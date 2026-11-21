-- Profile card: stop aggregating gift_logs on every profile open.
--
-- Opening a profile ran a SUM over every gift the user ever sent and a GROUP BY
-- over every gift they ever received. On a 2.4M-row table that is two large
-- scans per tap, which is what made a seat tap take tens of seconds.
--
-- This keeps two rollups exact with a trigger, and adds one RPC that returns
-- the whole profile card so the client stops making eleven round trips.
--
-- Nothing is dropped. user_total_sent and user_received_gifts_summary keep the
-- same names, arguments and result shapes, so installed app versions and the
-- dashboards keep working; they just read the rollups now.

-- ---------------------------------------------------------------------------
-- 1. Rollup tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_gift_rollups (
  user_id         uuid PRIMARY KEY,
  total_sent      bigint NOT NULL DEFAULT 0,
  sent_count      bigint NOT NULL DEFAULT 0,
  total_received  bigint NOT NULL DEFAULT 0,
  received_count  bigint NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_received_gift_counts (
  user_id    uuid   NOT NULL,
  gift_id    uuid   NOT NULL,
  gift_count bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, gift_id)
);

-- Serves "top N gifts this user received" directly.
CREATE INDEX IF NOT EXISTS user_received_gift_counts_top_idx
  ON public.user_received_gift_counts (user_id, gift_count DESC);

-- Read through the SECURITY DEFINER functions below only.
ALTER TABLE public.user_gift_rollups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_received_gift_counts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_gift_rollups FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.user_received_gift_counts FROM PUBLIC, anon, authenticated;

-- Tracks how much history the trigger is responsible for, so the backfill below
-- can be re-run without double counting.
CREATE TABLE IF NOT EXISTS public.gift_rollup_state (
  id            int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  baseline_at   timestamptz,
  backfilled_at timestamptz
);
ALTER TABLE public.gift_rollup_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.gift_rollup_state FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Keep the rollups exact going forward
-- ---------------------------------------------------------------------------
-- send_gift already updates the sender's and receiver's users row inside the
-- same transaction, so these upserts add no new row-lock contention class.
CREATE OR REPLACE FUNCTION public.trg_gift_logs_bump_rollups()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_amount bigint := COALESCE(NEW.amount, 0)::bigint;
  v_charm  bigint := COALESCE(NEW.charm_amount, NEW.amount, 0)::bigint;
BEGIN
  IF NEW.sender_id IS NOT NULL THEN
    INSERT INTO public.user_gift_rollups AS r
      (user_id, total_sent, sent_count, updated_at)
    VALUES (NEW.sender_id, v_amount, 1, now())
    ON CONFLICT (user_id) DO UPDATE
      SET total_sent = r.total_sent + EXCLUDED.total_sent,
          sent_count = r.sent_count + EXCLUDED.sent_count,
          updated_at = now();
  END IF;

  IF NEW.receiver_id IS NOT NULL THEN
    INSERT INTO public.user_gift_rollups AS r
      (user_id, total_received, received_count, updated_at)
    VALUES (NEW.receiver_id, v_charm, 1, now())
    ON CONFLICT (user_id) DO UPDATE
      SET total_received = r.total_received + EXCLUDED.total_received,
          received_count = r.received_count + EXCLUDED.received_count,
          updated_at = now();

    IF NEW.gift_id IS NOT NULL THEN
      INSERT INTO public.user_received_gift_counts AS c
        (user_id, gift_id, gift_count, updated_at)
      VALUES (NEW.receiver_id, NEW.gift_id, 1, now())
      ON CONFLICT (user_id, gift_id) DO UPDATE
        SET gift_count = c.gift_count + 1,
            updated_at = now();
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.trg_gift_logs_bump_rollups() FROM PUBLIC;

-- Short transaction: creating the trigger takes a brief exclusive lock on
-- gift_logs, and the baseline is captured while holding it so the backfill and
-- the trigger cannot count the same row twice.
BEGIN;
  DROP TRIGGER IF EXISTS trg_gift_logs_rollups ON public.gift_logs;
  CREATE TRIGGER trg_gift_logs_rollups
    AFTER INSERT ON public.gift_logs
    FOR EACH ROW EXECUTE FUNCTION public.trg_gift_logs_bump_rollups();

  INSERT INTO public.gift_rollup_state (id, baseline_at)
  VALUES (1, now())
  ON CONFLICT (id) DO UPDATE
    SET baseline_at = COALESCE(public.gift_rollup_state.baseline_at, EXCLUDED.baseline_at);
COMMIT;

-- ---------------------------------------------------------------------------
-- 3. One-time backfill of everything older than the baseline
-- ---------------------------------------------------------------------------
-- Runs outside the trigger transaction so gifting is never blocked by it, and
-- guards itself so re-applying this migration cannot double count.
DO $$
DECLARE
  v_baseline timestamptz;
  v_done     timestamptz;
BEGIN
  SELECT baseline_at, backfilled_at INTO v_baseline, v_done
  FROM public.gift_rollup_state WHERE id = 1;

  IF v_done IS NOT NULL THEN
    RAISE NOTICE 'gift rollups already backfilled at %', v_done;
    RETURN;
  END IF;

  INSERT INTO public.user_gift_rollups AS r (user_id, total_sent, sent_count)
  SELECT g.sender_id,
         COALESCE(SUM(g.amount), 0)::bigint,
         COUNT(*)::bigint
  FROM public.gift_logs g
  WHERE g.sender_id IS NOT NULL
    AND g.created_at < v_baseline
  GROUP BY g.sender_id
  ON CONFLICT (user_id) DO UPDATE
    SET total_sent = r.total_sent + EXCLUDED.total_sent,
        sent_count = r.sent_count + EXCLUDED.sent_count;

  INSERT INTO public.user_gift_rollups AS r
    (user_id, total_received, received_count)
  SELECT g.receiver_id,
         COALESCE(SUM(COALESCE(g.charm_amount, g.amount)), 0)::bigint,
         COUNT(*)::bigint
  FROM public.gift_logs g
  WHERE g.receiver_id IS NOT NULL
    AND g.created_at < v_baseline
  GROUP BY g.receiver_id
  ON CONFLICT (user_id) DO UPDATE
    SET total_received = r.total_received + EXCLUDED.total_received,
        received_count = r.received_count + EXCLUDED.received_count;

  INSERT INTO public.user_received_gift_counts AS c
    (user_id, gift_id, gift_count)
  SELECT g.receiver_id, g.gift_id, COUNT(*)::bigint
  FROM public.gift_logs g
  WHERE g.receiver_id IS NOT NULL
    AND g.gift_id IS NOT NULL
    AND g.created_at < v_baseline
  GROUP BY g.receiver_id, g.gift_id
  ON CONFLICT (user_id, gift_id) DO UPDATE
    SET gift_count = c.gift_count + EXCLUDED.gift_count;

  UPDATE public.gift_rollup_state SET backfilled_at = now() WHERE id = 1;
END
$$;

-- Repair hatch: recomputes one user from gift_logs when a number ever looks
-- wrong. Exact, and cheap for a single user once the indexes below exist.
CREATE OR REPLACE FUNCTION public.recompute_user_gift_rollup(p_user uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  INSERT INTO public.user_gift_rollups AS r
    (user_id, total_sent, sent_count, total_received, received_count, updated_at)
  SELECT p_user,
         COALESCE((SELECT SUM(amount) FROM public.gift_logs WHERE sender_id = p_user), 0),
         COALESCE((SELECT COUNT(*) FROM public.gift_logs WHERE sender_id = p_user), 0),
         COALESCE((SELECT SUM(COALESCE(charm_amount, amount)) FROM public.gift_logs WHERE receiver_id = p_user), 0),
         COALESCE((SELECT COUNT(*) FROM public.gift_logs WHERE receiver_id = p_user), 0),
         now()
  ON CONFLICT (user_id) DO UPDATE
    SET total_sent = EXCLUDED.total_sent,
        sent_count = EXCLUDED.sent_count,
        total_received = EXCLUDED.total_received,
        received_count = EXCLUDED.received_count,
        updated_at = now();

  DELETE FROM public.user_received_gift_counts WHERE user_id = p_user;
  INSERT INTO public.user_received_gift_counts (user_id, gift_id, gift_count)
  SELECT p_user, gift_id, COUNT(*)::bigint
  FROM public.gift_logs
  WHERE receiver_id = p_user AND gift_id IS NOT NULL
  GROUP BY gift_id;
END
$$;
REVOKE ALL ON FUNCTION public.recompute_user_gift_rollup(uuid) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 4. Same functions, now reading the rollups
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.user_total_sent(p_user uuid)
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT total_sent FROM public.user_gift_rollups WHERE user_id = p_user),
    0
  )::bigint;
$$;

CREATE OR REPLACE FUNCTION public.user_received_gifts_summary(
  p_user uuid, p_limit int DEFAULT 10
)
RETURNS TABLE (id uuid, name text, image_url text, count bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.gift_id, si.name, si.image_url, c.gift_count
  FROM public.user_received_gift_counts c
  JOIN public.shop_items si ON si.id = c.gift_id
  WHERE c.user_id = p_user
  ORDER BY c.gift_count DESC
  LIMIT GREATEST(p_limit, 0);
$$;

-- ---------------------------------------------------------------------------
-- 5. One call for the whole profile card
-- ---------------------------------------------------------------------------
-- Replaces the client's fan-out of eleven queries. Shapes match what the app
-- already builds, so the widgets need no changes beyond calling this.
CREATE OR REPLACE FUNCTION public.profile_card_bundle(
  p_user uuid, p_viewer uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user       jsonb;
  v_couple     record;
  v_has_couple boolean := false;
  v_visits     bigint := 0;
  v_result     jsonb;
BEGIN
  -- Same columns the client's select('*, family:families(...)') returned, so
  -- the profile widgets see an identical map.
  SELECT to_jsonb(u)
       || jsonb_build_object(
            'family',
            (SELECT jsonb_build_object('id', f.id, 'name', f.name, 'avatar_url', f.avatar_url)
             FROM public.families f WHERE f.id = u.family_id)
          )
    INTO v_user
  FROM public.users u
  WHERE u.id = p_user;

  IF v_user IS NULL THEN
    RETURN NULL;
  END IF;

  BEGIN
    SELECT COALESCE(public.get_profile_visit_count(p_user), 0) INTO v_visits;
  EXCEPTION WHEN undefined_function OR undefined_table THEN
    v_visits := 0;
  END;

  SELECT c.* INTO v_couple
  FROM public.couples c
  WHERE c.user1_id = p_user OR c.user2_id = p_user
  ORDER BY c.cp_level DESC NULLS LAST
  LIMIT 1;
  v_has_couple := FOUND;

  v_result := v_user || jsonb_build_object(
    'stats', jsonb_build_object(
      'following', (SELECT COUNT(*) FROM public.follows WHERE follower_id = p_user),
      'followers', (SELECT COUNT(*) FROM public.follows WHERE following_id = p_user),
      'charm', COALESCE((v_user->>'charm_value')::bigint, 0),
      'visits', v_visits
    ),
    'total_sent', COALESCE(
      (SELECT total_sent FROM public.user_gift_rollups WHERE user_id = p_user), 0
    ),
    'gifts', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id', t.gift_id, 'name', t.name,
               'image_url', t.image_url, 'count', t.gift_count)
             ORDER BY t.gift_count DESC)
      FROM (
        SELECT c.gift_id, c.gift_count, si.name, si.image_url
        FROM public.user_received_gift_counts c
        JOIN public.shop_items si ON si.id = c.gift_id
        WHERE c.user_id = p_user
        ORDER BY c.gift_count DESC
        LIMIT 10
      ) t
    ), '[]'::jsonb),
    'frames', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id', si.id, 'name', si.name,
               'image_url', si.image_url, 'svga_url', si.svga_url))
      FROM public.user_inventory ui
      JOIN public.shop_items si ON si.id = ui.item_id
      LEFT JOIN public.shop_categories sc ON sc.id = si.category_id
      WHERE ui.user_id = p_user
        AND (ui.expires_at IS NULL OR ui.expires_at > now())
        AND lower(COALESCE(sc.name, '')) LIKE '%frame%'
    ), '[]'::jsonb),
    'cars', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id', si.id, 'name', si.name,
               'image_url', si.image_url, 'svga_url', si.svga_url))
      FROM public.user_inventory ui
      JOIN public.shop_items si ON si.id = ui.item_id
      LEFT JOIN public.shop_categories sc ON sc.id = si.category_id
      WHERE ui.user_id = p_user
        AND (ui.expires_at IS NULL OR ui.expires_at > now())
        AND (lower(COALESCE(sc.name, '')) LIKE '%car%'
          OR lower(COALESCE(sc.name, '')) LIKE '%entrance%'
          OR lower(COALESCE(sc.name, '')) LIKE '%ride%')
    ), '[]'::jsonb),
    'cp_data', CASE WHEN NOT v_has_couple THEN NULL ELSE jsonb_build_object(
      'cp_level', COALESCE(v_couple.cp_level, 0),
      'cp_exp', v_couple.cp_exp,
      'created_at', v_couple.created_at,
      'badge_url', (SELECT badge_url FROM public.cp_level_configs
                    WHERE level = GREATEST(COALESCE(v_couple.cp_level, 1), 1)),
      'partner', (
        SELECT jsonb_build_object('id', pu.id, 'username', pu.username,
                                  'avatar_url', pu.avatar_url)
        FROM public.users pu
        WHERE pu.id = CASE WHEN v_couple.user1_id = p_user
                           THEN v_couple.user2_id ELSE v_couple.user1_id END
      )
    ) END,
    'is_following', CASE WHEN p_viewer IS NULL THEN NULL ELSE EXISTS(
      SELECT 1 FROM public.follows
      WHERE follower_id = p_viewer AND following_id = p_user
    ) END
  );

  RETURN v_result;
END
$$;
GRANT EXECUTE ON FUNCTION public.profile_card_bundle(uuid, uuid) TO authenticated;

ANALYZE public.user_gift_rollups;
ANALYZE public.user_received_gift_counts;

-- The indexes this file's backfill and repair path depend on live in
-- 20261121120000_live_room_hot_path_indexes.sql, which is the transaction-free
-- file. Apply that one first.
