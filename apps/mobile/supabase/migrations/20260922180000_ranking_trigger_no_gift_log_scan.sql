-- Fast rankings (Rave Star parity): O(1) gift_logs AFTER INSERT deltas;
-- cron only rewrites ranks / rolls periods — must not scan gift_logs.
-- Adapted for SK Live scoring: gift=amount, charm=COALESCE(charm_amount, amount).

SELECT pg_advisory_xact_lock(8412001);

-- ─── period_start on boards ─────────────────────────────────────────────────
ALTER TABLE public.gift_rankings
  ADD COLUMN IF NOT EXISTS period_start timestamptz;
ALTER TABLE public.charm_rankings
  ADD COLUMN IF NOT EXISTS period_start timestamptz;
ALTER TABLE public.room_rankings
  ADD COLUMN IF NOT EXISTS period_start timestamptz;
ALTER TABLE public.agency_rankings
  ADD COLUMN IF NOT EXISTS period_start timestamptz;
ALTER TABLE public.game_rankings
  ADD COLUMN IF NOT EXISTS period_start timestamptz;

UPDATE public.gift_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END
WHERE period_start IS NULL;

UPDATE public.charm_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END
WHERE period_start IS NULL;

UPDATE public.room_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END
WHERE period_start IS NULL;

UPDATE public.agency_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END
WHERE period_start IS NULL;

UPDATE public.game_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END
WHERE period_start IS NULL;

-- Home party list: incremental 30m gift score (no live gift_logs scan).
ALTER TABLE public.room_stats
  ADD COLUMN IF NOT EXISTS recent_gift_score bigint NOT NULL DEFAULT 0;
ALTER TABLE public.room_stats
  ADD COLUMN IF NOT EXISTS recent_gift_window_start timestamptz;

-- Game win index for throttled refresh / trigger period filters.
CREATE INDEX IF NOT EXISTS transactions_game_win_created_idx
  ON public.transactions (created_at DESC)
  WHERE transaction_type = 'game_win';

-- ─── One-time full seed with CURRENT (pre-replace) refresh functions ────────
-- Best-effort; if lock held or empty DB, trigger will fill going forward.
DO $$
BEGIN
  PERFORM set_config('statement_timeout', '120s', true);
  BEGIN
    PERFORM public.refresh_gift_rankings();
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'seed refresh_gift_rankings: %', SQLERRM;
  END;
  BEGIN
    PERFORM public.refresh_charm_rankings();
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'seed refresh_charm_rankings: %', SQLERRM;
  END;
  BEGIN
    PERFORM public.refresh_room_rankings();
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'seed refresh_room_rankings: %', SQLERRM;
  END;
  BEGIN
    PERFORM public.refresh_agency_rankings();
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'seed refresh_agency_rankings: %', SQLERRM;
  END;
  BEGIN
    PERFORM public.refresh_game_rankings();
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'seed refresh_game_rankings: %', SQLERRM;
  END;
END $$;

-- Re-stamp period_start after seed (old refresh did not set it).
UPDATE public.gift_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END;

UPDATE public.charm_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END;

UPDATE public.room_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END;

UPDATE public.agency_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END;

UPDATE public.game_rankings
SET period_start = CASE ranking_type
  WHEN 'daily' THEN date_trunc('day', now())
  WHEN 'weekly' THEN date_trunc('week', now())
  ELSE date_trunc('month', now())
END;

-- Seed recent_gift_score from last 30 minutes once.
UPDATE public.room_stats rs
SET recent_gift_score = COALESCE(x.score, 0),
    recent_gift_window_start = now() - interval '30 minutes',
    updated_at = now()
FROM (
  SELECT gl.room_id, COALESCE(SUM(gl.amount), 0)::bigint AS score
  FROM public.gift_logs gl
  WHERE gl.room_id IS NOT NULL
    AND gl.created_at >= (now() - interval '30 minutes')
  GROUP BY gl.room_id
) x
WHERE rs.room_id = x.room_id;

INSERT INTO public.room_stats (room_id, recent_gift_score, recent_gift_window_start, updated_at)
SELECT x.room_id, x.score, now() - interval '30 minutes', now()
FROM (
  SELECT gl.room_id, COALESCE(SUM(gl.amount), 0)::bigint AS score
  FROM public.gift_logs gl
  WHERE gl.room_id IS NOT NULL
    AND gl.created_at >= (now() - interval '30 minutes')
  GROUP BY gl.room_id
) x
ON CONFLICT (room_id) DO NOTHING;

-- ─── Delta upsert ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ranking_apply_delta(
  p_board text,
  p_id uuid,
  p_type text,
  p_period timestamptz,
  p_score bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
BEGIN
  IF p_id IS NULL OR COALESCE(p_score, 0) = 0 THEN
    RETURN;
  END IF;
  IF p_type NOT IN ('daily', 'weekly', 'monthly') THEN
    RETURN;
  END IF;

  IF p_board = 'gift' THEN
    INSERT INTO public.gift_rankings (user_id, score, rank, ranking_type, period_start)
    VALUES (p_id, p_score, 0, p_type, p_period)
    ON CONFLICT (user_id, ranking_type) DO UPDATE
    SET score = CASE
          WHEN public.gift_rankings.period_start IS NOT DISTINCT FROM EXCLUDED.period_start
            THEN public.gift_rankings.score + EXCLUDED.score
          ELSE EXCLUDED.score
        END,
        period_start = EXCLUDED.period_start;

  ELSIF p_board = 'charm' THEN
    INSERT INTO public.charm_rankings (user_id, score, rank, ranking_type, period_start)
    VALUES (p_id, p_score, 0, p_type, p_period)
    ON CONFLICT (user_id, ranking_type) DO UPDATE
    SET score = CASE
          WHEN public.charm_rankings.period_start IS NOT DISTINCT FROM EXCLUDED.period_start
            THEN public.charm_rankings.score + EXCLUDED.score
          ELSE EXCLUDED.score
        END,
        period_start = EXCLUDED.period_start;

  ELSIF p_board = 'room' THEN
    INSERT INTO public.room_rankings (room_id, score, rank, ranking_type, period_start, updated_at)
    VALUES (p_id, p_score, 0, p_type, p_period, now())
    ON CONFLICT (room_id, ranking_type) DO UPDATE
    SET score = CASE
          WHEN public.room_rankings.period_start IS NOT DISTINCT FROM EXCLUDED.period_start
            THEN public.room_rankings.score + EXCLUDED.score
          ELSE EXCLUDED.score
        END,
        period_start = EXCLUDED.period_start,
        updated_at = now();

  ELSIF p_board = 'agency' THEN
    INSERT INTO public.agency_rankings (agency_id, score, rank, ranking_type, period_start, updated_at)
    VALUES (p_id, p_score, 0, p_type, p_period, now())
    ON CONFLICT (agency_id, ranking_type) DO UPDATE
    SET score = CASE
          WHEN public.agency_rankings.period_start IS NOT DISTINCT FROM EXCLUDED.period_start
            THEN public.agency_rankings.score + EXCLUDED.score
          ELSE EXCLUDED.score
        END,
        period_start = EXCLUDED.period_start,
        updated_at = now();

  ELSIF p_board = 'game' THEN
    INSERT INTO public.game_rankings (user_id, score, rank, ranking_type, period_start, updated_at)
    VALUES (p_id, p_score, 0, p_type, p_period, now())
    ON CONFLICT (user_id, ranking_type) DO UPDATE
    SET score = CASE
          WHEN public.game_rankings.period_start IS NOT DISTINCT FROM EXCLUDED.period_start
            THEN public.game_rankings.score + EXCLUDED.score
          ELSE EXCLUDED.score
        END,
        period_start = EXCLUDED.period_start,
        updated_at = now();
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.ranking_apply_delta(text, uuid, text, timestamptz, bigint) FROM PUBLIC;

-- ─── Gift insert → bump boards + 30m room score ─────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_gift_logs_bump_rankings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_gift bigint;
  v_charm bigint;
  v_day timestamptz := date_trunc('day', now());
  v_week timestamptz := date_trunc('week', now());
  v_month timestamptz := date_trunc('month', now());
  v_agency uuid;
  v_window_start timestamptz;
  v_window_score bigint;
BEGIN
  IF NEW.created_at IS NULL THEN
    RETURN NEW;
  END IF;

  v_gift := COALESCE(NEW.amount, 0)::bigint;
  v_charm := COALESCE(NEW.charm_amount, NEW.amount, 0)::bigint;

  -- Gift (sender spend)
  IF NEW.sender_id IS NOT NULL AND v_gift > 0 AND NEW.created_at >= v_month THEN
    IF NEW.created_at >= v_day THEN
      PERFORM public.ranking_apply_delta('gift', NEW.sender_id, 'daily', v_day, v_gift);
    END IF;
    IF NEW.created_at >= v_week THEN
      PERFORM public.ranking_apply_delta('gift', NEW.sender_id, 'weekly', v_week, v_gift);
    END IF;
    PERFORM public.ranking_apply_delta('gift', NEW.sender_id, 'monthly', v_month, v_gift);
  END IF;

  -- Charm (receiver)
  IF NEW.receiver_id IS NOT NULL AND v_charm > 0 AND NEW.created_at >= v_month THEN
    IF NEW.created_at >= v_day THEN
      PERFORM public.ranking_apply_delta('charm', NEW.receiver_id, 'daily', v_day, v_charm);
    END IF;
    IF NEW.created_at >= v_week THEN
      PERFORM public.ranking_apply_delta('charm', NEW.receiver_id, 'weekly', v_week, v_charm);
    END IF;
    PERFORM public.ranking_apply_delta('charm', NEW.receiver_id, 'monthly', v_month, v_charm);

    SELECT am.agency_id INTO v_agency
    FROM public.agency_members am
    WHERE am.user_id = NEW.receiver_id
    LIMIT 1;

    IF v_agency IS NOT NULL THEN
      IF NEW.created_at >= v_day THEN
        PERFORM public.ranking_apply_delta('agency', v_agency, 'daily', v_day, v_charm);
      END IF;
      IF NEW.created_at >= v_week THEN
        PERFORM public.ranking_apply_delta('agency', v_agency, 'weekly', v_week, v_charm);
      END IF;
      PERFORM public.ranking_apply_delta('agency', v_agency, 'monthly', v_month, v_charm);
    END IF;
  END IF;

  -- Room period boards + rolling 30m score for home list
  IF NEW.room_id IS NOT NULL AND v_gift > 0 AND NEW.created_at >= v_month THEN
    IF NEW.created_at >= v_day THEN
      PERFORM public.ranking_apply_delta('room', NEW.room_id, 'daily', v_day, v_gift);
    END IF;
    IF NEW.created_at >= v_week THEN
      PERFORM public.ranking_apply_delta('room', NEW.room_id, 'weekly', v_week, v_gift);
    END IF;
    PERFORM public.ranking_apply_delta('room', NEW.room_id, 'monthly', v_month, v_gift);

    IF NEW.created_at >= (now() - interval '30 minutes') THEN
      INSERT INTO public.room_stats (room_id, recent_gift_score, recent_gift_window_start, updated_at)
      VALUES (NEW.room_id, v_gift, now() - interval '30 minutes', now())
      ON CONFLICT (room_id) DO UPDATE
      SET recent_gift_score = CASE
            WHEN public.room_stats.recent_gift_window_start IS NULL
              OR public.room_stats.recent_gift_window_start < (now() - interval '30 minutes')
              THEN v_gift
            ELSE public.room_stats.recent_gift_score + v_gift
          END,
          recent_gift_window_start = CASE
            WHEN public.room_stats.recent_gift_window_start IS NULL
              OR public.room_stats.recent_gift_window_start < (now() - interval '30 minutes')
              THEN now() - interval '30 minutes'
            ELSE public.room_stats.recent_gift_window_start
          END,
          updated_at = now();
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_gift_logs_bump_rankings() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_gift_logs_bump_rankings ON public.gift_logs;
CREATE TRIGGER trg_gift_logs_bump_rankings
  AFTER INSERT ON public.gift_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_gift_logs_bump_rankings();

-- Game wins → game board
CREATE OR REPLACE FUNCTION public.trg_transactions_bump_game_rankings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_score bigint;
  v_day timestamptz := date_trunc('day', now());
  v_week timestamptz := date_trunc('week', now());
  v_month timestamptz := date_trunc('month', now());
BEGIN
  IF NEW.transaction_type IS DISTINCT FROM 'game_win' THEN
    RETURN NEW;
  END IF;
  IF NEW.user_id IS NULL OR NEW.created_at IS NULL THEN
    RETURN NEW;
  END IF;

  v_score := COALESCE(NEW.amount, 0)::bigint;
  IF v_score <= 0 OR NEW.created_at < v_month THEN
    RETURN NEW;
  END IF;

  IF NEW.created_at >= v_day THEN
    PERFORM public.ranking_apply_delta('game', NEW.user_id, 'daily', v_day, v_score);
  END IF;
  IF NEW.created_at >= v_week THEN
    PERFORM public.ranking_apply_delta('game', NEW.user_id, 'weekly', v_week, v_score);
  END IF;
  PERFORM public.ranking_apply_delta('game', NEW.user_id, 'monthly', v_month, v_score);

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_transactions_bump_game_rankings() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_transactions_bump_game_rankings ON public.transactions;
CREATE TRIGGER trg_transactions_bump_game_rankings
  AFTER INSERT ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_transactions_bump_game_rankings();

-- ─── Light refresh: rank rewrite only (no gift_logs) ────────────────────────
CREATE OR REPLACE FUNCTION public.refresh_gift_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_gift_rankings')) THEN
    RETURN;
  END IF;
  PERFORM set_config('statement_timeout', '3s', true);

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    v_start := CASE v_type
      WHEN 'daily' THEN date_trunc('day', now())
      WHEN 'weekly' THEN date_trunc('week', now())
      ELSE date_trunc('month', now())
    END;

    DELETE FROM public.gift_rankings
    WHERE ranking_type = v_type
      AND period_start IS DISTINCT FROM v_start;

    UPDATE public.gift_rankings g
    SET rank = r.rn
    FROM (
      SELECT user_id,
             row_number() OVER (ORDER BY score DESC, user_id) AS rn
      FROM public.gift_rankings
      WHERE ranking_type = v_type
    ) r
    WHERE g.ranking_type = v_type
      AND g.user_id = r.user_id
      AND g.rank IS DISTINCT FROM r.rn;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_charm_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_charm_rankings')) THEN
    RETURN;
  END IF;
  PERFORM set_config('statement_timeout', '3s', true);

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    v_start := CASE v_type
      WHEN 'daily' THEN date_trunc('day', now())
      WHEN 'weekly' THEN date_trunc('week', now())
      ELSE date_trunc('month', now())
    END;

    DELETE FROM public.charm_rankings
    WHERE ranking_type = v_type
      AND period_start IS DISTINCT FROM v_start;

    UPDATE public.charm_rankings g
    SET rank = r.rn
    FROM (
      SELECT user_id,
             row_number() OVER (ORDER BY score DESC, user_id) AS rn
      FROM public.charm_rankings
      WHERE ranking_type = v_type
    ) r
    WHERE g.ranking_type = v_type
      AND g.user_id = r.user_id
      AND g.rank IS DISTINCT FROM r.rn;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_room_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_room_rankings')) THEN
    RETURN;
  END IF;
  PERFORM set_config('statement_timeout', '3s', true);

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    v_start := CASE v_type
      WHEN 'daily' THEN date_trunc('day', now())
      WHEN 'weekly' THEN date_trunc('week', now())
      ELSE date_trunc('month', now())
    END;

    DELETE FROM public.room_rankings
    WHERE ranking_type = v_type
      AND period_start IS DISTINCT FROM v_start;

    UPDATE public.room_rankings g
    SET rank = r.rn,
        updated_at = now()
    FROM (
      SELECT room_id,
             row_number() OVER (ORDER BY score DESC, room_id) AS rn
      FROM public.room_rankings
      WHERE ranking_type = v_type
    ) r
    WHERE g.ranking_type = v_type
      AND g.room_id = r.room_id
      AND g.rank IS DISTINCT FROM r.rn;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_agency_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_agency_rankings')) THEN
    RETURN;
  END IF;
  PERFORM set_config('statement_timeout', '3s', true);

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    v_start := CASE v_type
      WHEN 'daily' THEN date_trunc('day', now())
      WHEN 'weekly' THEN date_trunc('week', now())
      ELSE date_trunc('month', now())
    END;

    DELETE FROM public.agency_rankings
    WHERE ranking_type = v_type
      AND period_start IS DISTINCT FROM v_start;

    UPDATE public.agency_rankings g
    SET rank = r.rn,
        updated_at = now()
    FROM (
      SELECT agency_id,
             row_number() OVER (ORDER BY score DESC, agency_id) AS rn
      FROM public.agency_rankings
      WHERE ranking_type = v_type
    ) r
    WHERE g.ranking_type = v_type
      AND g.agency_id = r.agency_id
      AND g.rank IS DISTINCT FROM r.rn;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_game_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_game_rankings')) THEN
    RETURN;
  END IF;
  PERFORM set_config('statement_timeout', '3s', true);

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    v_start := CASE v_type
      WHEN 'daily' THEN date_trunc('day', now())
      WHEN 'weekly' THEN date_trunc('week', now())
      ELSE date_trunc('month', now())
    END;

    DELETE FROM public.game_rankings
    WHERE ranking_type = v_type
      AND period_start IS DISTINCT FROM v_start;

    UPDATE public.game_rankings g
    SET rank = r.rn,
        updated_at = now()
    FROM (
      SELECT user_id,
             row_number() OVER (ORDER BY score DESC, user_id) AS rn
      FROM public.game_rankings
      WHERE ranking_type = v_type
    ) r
    WHERE g.ranking_type = v_type
      AND g.user_id = r.user_id
      AND g.rank IS DISTINCT FROM r.rn;
  END LOOP;
END;
$$;

-- Expire stale 30m windows so home list does not keep forever-growing scores.
CREATE OR REPLACE FUNCTION public.refresh_room_recent_gift_windows()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_room_recent_gift')) THEN
    RETURN;
  END IF;
  UPDATE public.room_stats
  SET recent_gift_score = 0,
      recent_gift_window_start = now() - interval '30 minutes',
      updated_at = now()
  WHERE recent_gift_score > 0
    AND (
      recent_gift_window_start IS NULL
      OR recent_gift_window_start < (now() - interval '30 minutes')
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_gift_rankings() TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_charm_rankings() TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_room_rankings() TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_agency_rankings() TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_game_rankings() TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_room_recent_gift_windows() TO service_role;

-- Keep anon/authenticated grants for legacy callers but functions are now cheap.
GRANT EXECUTE ON FUNCTION public.refresh_gift_rankings() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_charm_rankings() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_room_rankings() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_agency_rankings() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_game_rankings() TO anon, authenticated;

-- ─── Cron: light boards (+ separate window cleanup) ─────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname IN ('refresh-rankings', 'refresh-rankings-light', 'refresh-room-recent-gift');

    PERFORM cron.schedule(
      'refresh-rankings-light',
      '*/2 * * * *',
      $cron$
        SELECT public.refresh_gift_rankings();
        SELECT public.refresh_charm_rankings();
        SELECT public.refresh_room_rankings();
        SELECT public.refresh_agency_rankings();
        SELECT public.refresh_game_rankings();
        SELECT public.refresh_room_recent_gift_windows();
      $cron$
    );
  END IF;
END $$;

-- ─── Home/party list: use room_stats.recent_gift_score ───────────────────────
DROP VIEW IF EXISTS public.active_rooms_with_rankings;

CREATE VIEW public.active_rooms_with_rankings AS
WITH room_seat_stats AS (
  SELECT
    s.room_id,
    COUNT(*)::int AS seated_users_count
  FROM public.room_seats s
  WHERE s.user_id IS NOT NULL
  GROUP BY s.room_id
),
room_recent_ranks AS (
  SELECT
    r.id AS room_id,
    CASE
      WHEN rs.recent_gift_window_start IS NULL
        OR rs.recent_gift_window_start < (now() - interval '30 minutes')
        THEN 0::bigint
      ELSE COALESCE(rs.recent_gift_score, 0)::bigint
    END AS ranking_score,
    COALESCE(ss.seated_users_count, 0)::int AS seated_users_count,
    ROW_NUMBER() OVER (
      ORDER BY COALESCE(ss.seated_users_count, 0) DESC,
               COALESCE(r.online_users_count, 0) DESC,
               CASE
                 WHEN rs.recent_gift_window_start IS NULL
                   OR rs.recent_gift_window_start < (now() - interval '30 minutes')
                   THEN 0::bigint
                 ELSE COALESCE(rs.recent_gift_score, 0)::bigint
               END DESC,
               r.created_at ASC,
               r.id ASC
    )::int AS recent_rank
  FROM public.rooms r
  LEFT JOIN public.room_stats rs ON rs.room_id = r.id
  LEFT JOIN room_seat_stats ss ON ss.room_id = r.id
  WHERE r.is_active = true
),
room_seat_avatars AS (
  SELECT
    room_id,
    jsonb_agg(avatar_url) AS avatars
  FROM (
    SELECT
      s.room_id,
      u.avatar_url,
      ROW_NUMBER() OVER (PARTITION BY s.room_id ORDER BY s.seat_index ASC) AS rank
    FROM public.room_seats s
    JOIN public.users u ON u.id = s.user_id
    WHERE s.user_id IS NOT NULL
  ) ranked
  WHERE rank <= 3
  GROUP BY room_id
)
SELECT
  r.id,
  r.short_id,
  r.host_id,
  r.title,
  r.theme,
  r.is_active,
  r.room_password,
  r.is_locked,
  r.created_at,
  r.room_topic,
  r.image_url,
  r.announcement,
  r.country_code,
  r.is_private,
  r.decoration_id,
  r.membership_tag_name,
  r.membership_tag_color,
  r.mic_count,
  r.party_mode,
  r.background_url,
  r.youtube_state,
  r.online_users_count,
  COALESCE(rr.seated_users_count, 0)::int AS seated_users_count,
  r.chat_cleared_at,
  r.admin_only_chat,
  r.is_pinned,
  r.pin_order,
  u.username AS host_name,
  u.avatar_url AS host_avatar,
  u.short_id AS host_short_id,
  u.vip_level AS host_vip_level,
  u.country_code AS host_country_code,
  COALESCE(vp.has_room_priority, false) AS has_room_priority,
  rr.recent_rank AS current_rank,
  rr.ranking_score,
  'daily'::text AS ranking_type,
  ra.badge_url AS rank_badge,
  ra.frame_url AS rank_frame,
  COALESCE(rsa.avatars, '[]'::jsonb) AS top_avatars
FROM public.rooms r
LEFT JOIN public.users u ON r.host_id = u.id
LEFT JOIN public.vip_plans vp ON u.vip_level = vp.level
LEFT JOIN room_recent_ranks rr ON rr.room_id = r.id
LEFT JOIN room_seat_avatars rsa ON rsa.room_id = r.id
LEFT JOIN public.ranking_assets ra
  ON rr.recent_rank = ra.rank_position
 AND ra.ranking_type = 'daily'
 AND ra.category = 'Room'
WHERE r.is_active = true;

GRANT SELECT ON public.active_rooms_with_rankings TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
