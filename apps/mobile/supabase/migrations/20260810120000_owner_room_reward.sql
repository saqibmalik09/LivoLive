-- Owner Profile Room Reward: daily energy/levels/claim window (clone of room gift box),
-- claimable only by rooms.host_id. Prize pool supports coins + shop assets with
-- optional duration_days override for expiry.

CREATE TABLE IF NOT EXISTS public.owner_room_reward_levels (
  level integer PRIMARY KEY CHECK (level BETWEEN 1 AND 5),
  required_points bigint NOT NULL CHECK (required_points > 0),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.owner_room_reward_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level integer NOT NULL REFERENCES public.owner_room_reward_levels (level) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  reward_type text NOT NULL DEFAULT 'coins'
    CHECK (reward_type IN ('coins', 'shop_item')),
  coin_amount integer NOT NULL DEFAULT 0 CHECK (coin_amount >= 0),
  shop_item_id uuid REFERENCES public.shop_items (id) ON DELETE SET NULL,
  duration_days integer NULL CHECK (duration_days IS NULL OR duration_days >= 0),
  weight integer NOT NULL DEFAULT 1 CHECK (weight > 0),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  is_featured boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS owner_room_reward_items_level_idx
  ON public.owner_room_reward_items (level, is_active, sort_order);

CREATE TABLE IF NOT EXISTS public.owner_room_reward_rules (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  rules jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.owner_room_reward_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
  level integer NOT NULL REFERENCES public.owner_room_reward_levels (level),
  reward_item_id uuid REFERENCES public.owner_room_reward_items (id) ON DELETE SET NULL,
  reward_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  period_key text NOT NULL DEFAULT to_char((now() AT TIME ZONE 'UTC+3'), 'YYYY-MM-DD'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, room_id, level, period_key)
);

CREATE INDEX IF NOT EXISTS owner_room_reward_claims_user_room_idx
  ON public.owner_room_reward_claims (user_id, room_id, period_key, created_at DESC);

CREATE TABLE IF NOT EXISTS public.owner_room_reward_claim_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
  level integer NOT NULL REFERENCES public.owner_room_reward_levels (level),
  period_key text NOT NULL,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'claimed', 'forfeited')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, room_id, level, period_key)
);

CREATE INDEX IF NOT EXISTS owner_room_reward_claim_windows_lookup_idx
  ON public.owner_room_reward_claim_windows (user_id, room_id, period_key, status);

INSERT INTO public.owner_room_reward_levels (level, required_points, sort_order)
VALUES
  (1, 100000, 1),
  (2, 500000, 2),
  (3, 2000000, 3),
  (4, 5000000, 4),
  (5, 12000000, 5)
ON CONFLICT (level) DO NOTHING;

INSERT INTO public.owner_room_reward_rules (id, rules)
VALUES (
  1,
  '[
    "As the room owner, contribute energy by sending gifts in your room. Gift coins count toward today''s progress.",
    "Progress and claimed boxes reset every day at 00:00 (UTC+3). You start again from LV1.",
    "When you unlock a level you have 2 minutes to claim. If you miss it, that level cannot be claimed that day and you move to the next level.",
    "Only the room owner can claim. Rewards may be coins or timed inventory items (frame, entrance, etc.) configured by the platform."
  ]'::jsonb
)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.owner_room_reward_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_room_reward_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_room_reward_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_room_reward_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_room_reward_claim_windows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS owner_room_reward_levels_read ON public.owner_room_reward_levels;
CREATE POLICY owner_room_reward_levels_read ON public.owner_room_reward_levels
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS owner_room_reward_items_read ON public.owner_room_reward_items;
CREATE POLICY owner_room_reward_items_read ON public.owner_room_reward_items
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS owner_room_reward_rules_read ON public.owner_room_reward_rules;
CREATE POLICY owner_room_reward_rules_read ON public.owner_room_reward_rules
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS owner_room_reward_claims_read_own ON public.owner_room_reward_claims;
CREATE POLICY owner_room_reward_claims_read_own ON public.owner_room_reward_claims
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS owner_room_reward_windows_read_own ON public.owner_room_reward_claim_windows;
CREATE POLICY owner_room_reward_windows_read_own ON public.owner_room_reward_claim_windows
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.get_owner_room_reward_progress(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_energy bigint := 0;
  v_current_level integer := 1;
  v_levels json;
  v_items json;
  v_claimed integer[];
  v_forfeited integer[];
  v_rules json;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_period text;
  v_seconds bigint;
  v_lvl record;
BEGIN
  IF p_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room required');
  END IF;

  SELECT r.host_id INTO v_host_id
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF v_host_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  SELECT d.day_start, d.day_end, d.period_key, d.seconds_remaining
  INTO v_day_start, v_day_end, v_period, v_seconds
  FROM public.room_reward_day_bounds(now()) d;

  IF v_user_id IS NOT NULL AND v_user_id = v_host_id THEN
    SELECT COALESCE(SUM(gl.amount), 0)::bigint
    INTO v_energy
    FROM public.gift_logs gl
    WHERE gl.room_id = p_room_id
      AND gl.sender_id = v_user_id
      AND gl.created_at >= v_day_start
      AND gl.created_at < v_day_end;

    UPDATE public.owner_room_reward_claim_windows w
    SET status = 'forfeited'
    WHERE w.user_id = v_user_id
      AND w.room_id = p_room_id
      AND w.period_key = v_period
      AND w.status = 'open'
      AND w.expires_at <= now();

    SELECT COALESCE(array_agg(c.level ORDER BY c.level), '{}')
    INTO v_claimed
    FROM public.owner_room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
      AND c.period_key = v_period;

    SELECT COALESCE(array_agg(w.level ORDER BY w.level), '{}')
    INTO v_forfeited
    FROM public.owner_room_reward_claim_windows w
    WHERE w.user_id = v_user_id
      AND w.room_id = p_room_id
      AND w.period_key = v_period
      AND w.status = 'forfeited';

    FOR v_lvl IN
      SELECT l.level, l.required_points
      FROM public.owner_room_reward_levels l
      WHERE l.is_active = true
      ORDER BY l.level ASC
    LOOP
      IF v_lvl.level = ANY (v_claimed) THEN
        CONTINUE;
      END IF;
      IF v_lvl.level = ANY (v_forfeited) THEN
        CONTINUE;
      END IF;
      IF v_energy < v_lvl.required_points THEN
        EXIT;
      END IF;

      INSERT INTO public.owner_room_reward_claim_windows (
        user_id, room_id, level, period_key, unlocked_at, expires_at, status
      ) VALUES (
        v_user_id, p_room_id, v_lvl.level, v_period,
        now(), now() + interval '2 minutes', 'open'
      )
      ON CONFLICT (user_id, room_id, level, period_key) DO NOTHING;

      EXIT;
    END LOOP;

    SELECT COALESCE(array_agg(w.level ORDER BY w.level), '{}')
    INTO v_forfeited
    FROM public.owner_room_reward_claim_windows w
    WHERE w.user_id = v_user_id
      AND w.room_id = p_room_id
      AND w.period_key = v_period
      AND w.status = 'forfeited';
  ELSE
    v_claimed := '{}';
    v_forfeited := '{}';
  END IF;

  SELECT COALESCE(
    (
      SELECT w.level
      FROM public.owner_room_reward_claim_windows w
      WHERE w.user_id = v_user_id
        AND w.room_id = p_room_id
        AND w.period_key = v_period
        AND w.status = 'open'
        AND w.expires_at > now()
        AND NOT (w.level = ANY (v_claimed))
      ORDER BY w.level ASC
      LIMIT 1
    ),
    (
      SELECT MAX(l.level)
      FROM public.owner_room_reward_levels l
      WHERE l.is_active = true
        AND v_energy >= l.required_points
    ),
    (
      SELECT MIN(l.level)
      FROM public.owner_room_reward_levels l
      WHERE l.is_active = true
    ),
    1
  )
  INTO v_current_level;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level), '[]'::json)
  INTO v_levels
  FROM (
    SELECT
      l.level,
      l.required_points,
      l.is_active,
      l.sort_order,
      (l.level = ANY (v_claimed)) AS claimed,
      (l.level = ANY (v_forfeited)) AS forfeited,
      (
        SELECT CASE
          WHEN w.status = 'open' AND w.expires_at > now()
            AND NOT (l.level = ANY (v_claimed))
          THEN true
          ELSE false
        END
        FROM public.owner_room_reward_claim_windows w
        WHERE w.user_id = v_user_id
          AND w.room_id = p_room_id
          AND w.level = l.level
          AND w.period_key = v_period
        LIMIT 1
      ) AS can_open,
      (
        SELECT GREATEST(
          0,
          FLOOR(EXTRACT(EPOCH FROM (w.expires_at - now())))
        )::int
        FROM public.owner_room_reward_claim_windows w
        WHERE w.user_id = v_user_id
          AND w.room_id = p_room_id
          AND w.level = l.level
          AND w.period_key = v_period
          AND w.status = 'open'
          AND w.expires_at > now()
        LIMIT 1
      ) AS claim_seconds_remaining,
      (
        SELECT w.expires_at
        FROM public.owner_room_reward_claim_windows w
        WHERE w.user_id = v_user_id
          AND w.room_id = p_room_id
          AND w.level = l.level
          AND w.period_key = v_period
        LIMIT 1
      ) AS claim_expires_at
    FROM public.owner_room_reward_levels l
    WHERE l.is_active = true
  ) t;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level, t.sort_order, t.created_at), '[]'::json)
  INTO v_items
  FROM (
    SELECT
      i.id,
      i.level,
      i.title,
      i.image_url,
      i.reward_type,
      i.coin_amount,
      i.shop_item_id,
      i.duration_days,
      i.weight,
      i.sort_order,
      i.is_featured,
      i.created_at
    FROM public.owner_room_reward_items i
    WHERE i.is_active = true
  ) t;

  SELECT r.rules INTO v_rules
  FROM public.owner_room_reward_rules r
  WHERE r.id = 1;

  RETURN json_build_object(
    'success', true,
    'is_owner', (v_user_id IS NOT NULL AND v_user_id = v_host_id),
    'host_id', v_host_id,
    'energy', v_energy,
    'current_level', v_current_level,
    'claimed_levels', to_json(v_claimed),
    'forfeited_levels', to_json(v_forfeited),
    'levels', v_levels,
    'items', v_items,
    'rules', COALESCE(v_rules, '[]'::json),
    'period_key', v_period,
    'seconds_remaining', v_seconds,
    'resets_at', v_day_end
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.open_owner_room_reward_box(
  p_room_id uuid,
  p_level integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_energy bigint := 0;
  v_required bigint;
  v_item public.owner_room_reward_items%ROWTYPE;
  v_total_weight integer;
  v_pick integer;
  v_running integer := 0;
  v_claim_id uuid;
  v_expires timestamptz;
  v_snapshot jsonb;
  v_duration integer;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_period text;
  v_win public.owner_room_reward_claim_windows%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 OR p_level > 5 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid params');
  END IF;

  SELECT r.host_id INTO v_host_id
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF v_host_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  IF v_user_id <> v_host_id THEN
    RETURN json_build_object('success', false, 'message', 'Only the room owner can claim');
  END IF;

  SELECT d.day_start, d.day_end, d.period_key
  INTO v_day_start, v_day_end, v_period
  FROM public.room_reward_day_bounds(now()) d;

  UPDATE public.owner_room_reward_claim_windows w
  SET status = 'forfeited'
  WHERE w.user_id = v_user_id
    AND w.room_id = p_room_id
    AND w.period_key = v_period
    AND w.status = 'open'
    AND w.expires_at <= now();

  SELECT l.required_points
  INTO v_required
  FROM public.owner_room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.owner_room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
      AND c.level = p_level
      AND c.period_key = v_period
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed today');
  END IF;

  SELECT * INTO v_win
  FROM public.owner_room_reward_claim_windows w
  WHERE w.user_id = v_user_id
    AND w.room_id = p_room_id
    AND w.level = p_level
    AND w.period_key = v_period;

  IF NOT FOUND OR v_win.status <> 'open' OR v_win.expires_at <= now() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Claim window expired (2 minutes). This level is locked for today.'
    );
  END IF;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_energy
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.sender_id = v_user_id
    AND gl.created_at >= v_day_start
    AND gl.created_at < v_day_end;

  IF v_energy < v_required THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Not enough energy',
      'energy', v_energy,
      'required', v_required
    );
  END IF;

  SELECT COALESCE(SUM(i.weight), 0)
  INTO v_total_weight
  FROM public.owner_room_reward_items i
  WHERE i.level = p_level
    AND i.is_active = true;

  IF v_total_weight <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No rewards configured');
  END IF;

  v_pick := 1 + floor(random() * v_total_weight)::integer;

  FOR v_item IN
    SELECT *
    FROM public.owner_room_reward_items i
    WHERE i.level = p_level
      AND i.is_active = true
    ORDER BY i.sort_order, i.created_at
  LOOP
    v_running := v_running + v_item.weight;
    IF v_running >= v_pick THEN
      EXIT;
    END IF;
  END LOOP;

  IF v_item.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Reward pick failed');
  END IF;

  v_snapshot := jsonb_build_object(
    'id', v_item.id,
    'title', v_item.title,
    'image_url', v_item.image_url,
    'reward_type', v_item.reward_type,
    'coin_amount', v_item.coin_amount,
    'shop_item_id', v_item.shop_item_id,
    'duration_days', v_item.duration_days,
    'level', p_level,
    'period_key', v_period
  );

  IF v_item.reward_type = 'coins' AND v_item.coin_amount > 0 THEN
    UPDATE public.users
    SET coins = coins + v_item.coin_amount
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id,
      v_item.coin_amount,
      'coin',
      'room_reward',
      p_room_id
    );
  ELSIF v_item.reward_type = 'shop_item' AND v_item.shop_item_id IS NOT NULL THEN
    SELECT COALESCE(v_item.duration_days, si.duration_days, 0)
    INTO v_duration
    FROM public.shop_items si
    WHERE si.id = v_item.shop_item_id
      AND si.is_active = true;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Shop item missing');
    END IF;

    v_expires := CASE
      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
      ELSE '9999-12-31'::timestamptz
    END;

    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
    VALUES (v_user_id, v_item.shop_item_id, 'owner_room_reward', v_expires)
    ON CONFLICT (user_id, item_id) DO UPDATE
      SET expires_at = GREATEST(public.user_inventory.expires_at, EXCLUDED.expires_at),
          source = COALESCE(public.user_inventory.source, EXCLUDED.source);

    v_snapshot := v_snapshot || jsonb_build_object(
      'expires_at', v_expires,
      'granted_duration_days', v_duration
    );
  END IF;

  INSERT INTO public.owner_room_reward_claims (
    user_id, room_id, level, reward_item_id, reward_snapshot, period_key
  ) VALUES (
    v_user_id, p_room_id, p_level, v_item.id, v_snapshot, v_period
  )
  RETURNING id INTO v_claim_id;

  UPDATE public.owner_room_reward_claim_windows
  SET status = 'claimed'
  WHERE user_id = v_user_id
    AND room_id = p_room_id
    AND level = p_level
    AND period_key = v_period;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'reward', v_snapshot,
    'period_key', v_period
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed today');
  WHEN others THEN
    RETURN json_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_owner_room_reward_claims(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_rows json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated', 'claims', '[]'::json);
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
  INTO v_rows
  FROM (
    SELECT
      c.id,
      c.level,
      c.reward_snapshot,
      c.created_at
    FROM public.owner_room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
  ) t;

  RETURN json_build_object('success', true, 'claims', v_rows);
END;
$function$;

GRANT SELECT ON public.owner_room_reward_levels TO anon, authenticated, service_role;
GRANT SELECT ON public.owner_room_reward_items TO anon, authenticated, service_role;
GRANT SELECT ON public.owner_room_reward_rules TO anon, authenticated, service_role;
GRANT SELECT ON public.owner_room_reward_claims TO authenticated, service_role;
GRANT SELECT ON public.owner_room_reward_claim_windows TO authenticated, service_role;
GRANT ALL ON public.owner_room_reward_levels TO service_role;
GRANT ALL ON public.owner_room_reward_items TO service_role;
GRANT ALL ON public.owner_room_reward_rules TO service_role;
GRANT ALL ON public.owner_room_reward_claims TO service_role;
GRANT ALL ON public.owner_room_reward_claim_windows TO service_role;

GRANT EXECUTE ON FUNCTION public.get_owner_room_reward_progress(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.open_owner_room_reward_box(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_owner_room_reward_claims(uuid) TO authenticated, service_role;
