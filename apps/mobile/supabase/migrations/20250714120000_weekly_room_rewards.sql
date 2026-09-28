-- Weekly Room Rewards (Charm Cup): Sunday–Saturday UTC+3 room gift totals; owner-only coin claims.

-- Allow transaction type for claims
DO $$
BEGIN
  ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
  ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_transaction_type_check
    CHECK (transaction_type = ANY (ARRAY[
      'recharge'::text,
      'gift_sent'::text,
      'gift_received'::text,
      'lucky_gift_bonus'::text,
      'game_win'::text,
      'game_loss'::text,
      'withdrawal'::text,
      'purchase'::text,
      'agency_commission'::text,
      'salary_payout'::text,
      'transfer_out'::text,
      'transfer_in'::text,
      'exchange'::text,
      'rupee_game_entry'::text,
      'rupee_game_refund'::text,
      'lucky_pro_gift_bonus'::text,
      'room_reward'::text,
      'weekly_room_reward'::text
    ]));
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'transactions check constraint update skipped: %', SQLERRM;
END $$;

CREATE TABLE IF NOT EXISTS public.weekly_room_reward_levels (
  level integer PRIMARY KEY CHECK (level BETWEEN 1 AND 5),
  required_points bigint NOT NULL CHECK (required_points > 0),
  coin_reward bigint NOT NULL CHECK (coin_reward >= 0),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.weekly_room_reward_rules (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  rules jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.weekly_room_reward_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  level integer NOT NULL REFERENCES public.weekly_room_reward_levels (level),
  period_key text NOT NULL,
  coin_amount bigint NOT NULL DEFAULT 0,
  claimed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (room_id, level, period_key)
);

CREATE INDEX IF NOT EXISTS weekly_room_reward_claims_room_period_idx
  ON public.weekly_room_reward_claims (room_id, period_key, claimed_at DESC);

INSERT INTO public.weekly_room_reward_levels (level, required_points, coin_reward, sort_order)
VALUES
  (1, 300000, 30000, 1),
  (2, 500000, 50000, 2),
  (3, 1000000, 100000, 3),
  (4, 2000000, 200000, 4),
  (5, 3000000, 300000, 5)
ON CONFLICT (level) DO NOTHING;

INSERT INTO public.weekly_room_reward_rules (id, rules)
VALUES (
  1,
  '[
    "Cycle Period: Every Sunday to the following Saturday (UTC+3).",
    "Corresponding rewards will be earned based on the Room Charm Value.",
    "The room owner is eligible for both coin rewards and item rewards.",
    "After each cycle ends, the room owner must manually claim rewards on the page.",
    "Rewards must be claimed within 6 days; expired rewards will disappear. Please claim your rewards in time.",
    "The successfully received rewards will be credited to your account within 1-2 working days."
  ]'::jsonb
)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.weekly_room_reward_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_room_reward_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_room_reward_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS weekly_room_reward_levels_read ON public.weekly_room_reward_levels;
CREATE POLICY weekly_room_reward_levels_read ON public.weekly_room_reward_levels
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS weekly_room_reward_rules_read ON public.weekly_room_reward_rules;
CREATE POLICY weekly_room_reward_rules_read ON public.weekly_room_reward_rules
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS weekly_room_reward_claims_read ON public.weekly_room_reward_claims;
CREATE POLICY weekly_room_reward_claims_read ON public.weekly_room_reward_claims
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

GRANT SELECT ON public.weekly_room_reward_levels TO anon, authenticated, service_role;
GRANT SELECT ON public.weekly_room_reward_rules TO anon, authenticated, service_role;
GRANT SELECT ON public.weekly_room_reward_claims TO authenticated, service_role;

-- Sunday 00:00 UTC+3 week helpers
CREATE OR REPLACE FUNCTION public.weekly_room_reward_week_bounds(p_at timestamptz DEFAULT now())
RETURNS TABLE (
  week_start timestamptz,
  week_end timestamptz,
  period_key text,
  claim_deadline timestamptz
)
LANGUAGE sql
STABLE
AS $$
  WITH local_ts AS (
    SELECT (p_at AT TIME ZONE 'UTC+3') AS local_at
  ),
  sunday AS (
    SELECT
      date_trunc('day', local_at)
        - ((EXTRACT(DOW FROM local_at)::integer) * interval '1 day') AS week_start_local
    FROM local_ts
  )
  SELECT
    (week_start_local AT TIME ZONE 'UTC+3') AS week_start,
    ((week_start_local + interval '7 days') AT TIME ZONE 'UTC+3') AS week_end,
    to_char(week_start_local, 'YYYY-MM-DD') AS period_key,
    ((week_start_local + interval '13 days') AT TIME ZONE 'UTC+3') AS claim_deadline
  FROM sunday;
$$;

CREATE OR REPLACE FUNCTION public.get_weekly_room_reward_progress(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_is_owner boolean := false;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_period_key text;
  v_claim_deadline timestamptz;
  v_charm bigint := 0;
  v_remaining bigint := 0;
  v_in_claim_window boolean := false;
  v_levels json;
  v_rules json;
BEGIN
  IF p_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid room');
  END IF;

  SELECT r.host_id INTO v_host_id
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  v_is_owner := (v_user_id IS NOT NULL AND v_user_id = v_host_id);

  SELECT w.week_start, w.week_end, w.period_key, w.claim_deadline
  INTO v_week_start, v_week_end, v_period_key, v_claim_deadline
  FROM public.weekly_room_reward_week_bounds(now()) w;

  v_remaining := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_week_end - now())))::bigint);
  v_in_claim_window := now() < v_claim_deadline;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_charm
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= v_week_start
    AND gl.created_at < v_week_end;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level), '[]'::json)
  INTO v_levels
  FROM (
    SELECT
      l.level,
      l.required_points,
      l.coin_reward,
      l.is_active,
      EXISTS (
        SELECT 1
        FROM public.weekly_room_reward_claims c
        WHERE c.room_id = p_room_id
          AND c.level = l.level
          AND c.period_key = v_period_key
      ) AS claimed,
      (
        v_is_owner
        AND l.is_active
        AND v_charm >= l.required_points
        AND v_in_claim_window
        AND NOT EXISTS (
          SELECT 1
          FROM public.weekly_room_reward_claims c
          WHERE c.room_id = p_room_id
            AND c.level = l.level
            AND c.period_key = v_period_key
        )
        AND (
          now() < v_week_end
          OR (now() >= v_week_end AND now() < v_claim_deadline)
        )
      ) AS can_claim,
      (
        NOT EXISTS (
          SELECT 1
          FROM public.weekly_room_reward_claims c
          WHERE c.room_id = p_room_id
            AND c.level = l.level
            AND c.period_key = v_period_key
        )
        AND v_charm >= l.required_points
        AND now() >= v_claim_deadline
      ) AS expired
    FROM public.weekly_room_reward_levels l
    ORDER BY l.sort_order, l.level
  ) t;

  SELECT COALESCE(r.rules, '[]'::jsonb)::json
  INTO v_rules
  FROM public.weekly_room_reward_rules r
  WHERE r.id = 1;

  RETURN json_build_object(
    'success', true,
    'charm', v_charm,
    'is_owner', v_is_owner,
    'period_key', v_period_key,
    'week_start', v_week_start,
    'week_end', v_week_end,
    'claim_deadline', v_claim_deadline,
    'remaining_seconds', v_remaining,
    'levels', COALESCE(v_levels, '[]'::json),
    'rules', COALESCE(v_rules, '[]'::json)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.claim_weekly_room_reward(
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
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_period_key text;
  v_claim_deadline timestamptz;
  v_charm bigint := 0;
  v_required bigint;
  v_coin_reward bigint;
  v_claim_id uuid;
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

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  IF v_user_id <> v_host_id THEN
    RETURN json_build_object('success', false, 'message', 'Only room owner can claim');
  END IF;

  SELECT w.week_start, w.week_end, w.period_key, w.claim_deadline
  INTO v_week_start, v_week_end, v_period_key, v_claim_deadline
  FROM public.weekly_room_reward_week_bounds(now()) w;

  IF now() >= v_claim_deadline THEN
    RETURN json_build_object('success', false, 'message', 'Claim window expired');
  END IF;

  SELECT l.required_points, l.coin_reward
  INTO v_required, v_coin_reward
  FROM public.weekly_room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.weekly_room_reward_claims c
    WHERE c.room_id = p_room_id
      AND c.level = p_level
      AND c.period_key = v_period_key
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  END IF;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_charm
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= v_week_start
    AND gl.created_at < v_week_end;

  IF v_charm < v_required THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Room target not reached',
      'charm', v_charm,
      'required', v_required
    );
  END IF;

  IF v_coin_reward > 0 THEN
    UPDATE public.users
    SET coins = coins + v_coin_reward
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id,
      v_coin_reward,
      'coin',
      'weekly_room_reward',
      p_room_id
    );
  END IF;

  INSERT INTO public.weekly_room_reward_claims (
    room_id, owner_id, level, period_key, coin_amount
  ) VALUES (
    p_room_id, v_user_id, p_level, v_period_key, v_coin_reward
  )
  RETURNING id INTO v_claim_id;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'level', p_level,
    'coin_amount', v_coin_reward,
    'period_key', v_period_key
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  WHEN others THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_weekly_room_reward_claims(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_rows json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated', 'claims', '[]'::json);
  END IF;

  SELECT r.host_id INTO v_host_id
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Room not found', 'claims', '[]'::json);
  END IF;

  IF v_user_id <> v_host_id THEN
    RETURN json_build_object('success', false, 'message', 'Owner only', 'claims', '[]'::json);
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.claimed_at DESC), '[]'::json)
  INTO v_rows
  FROM (
    SELECT
      c.id,
      c.level,
      c.period_key,
      c.coin_amount,
      c.claimed_at
    FROM public.weekly_room_reward_claims c
    WHERE c.room_id = p_room_id
      AND c.owner_id = v_user_id
    ORDER BY c.claimed_at DESC
    LIMIT 100
  ) t;

  RETURN json_build_object('success', true, 'claims', COALESCE(v_rows, '[]'::json));
END;
$function$;

GRANT EXECUTE ON FUNCTION public.weekly_room_reward_week_bounds(timestamptz) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_weekly_room_reward_progress(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_weekly_room_reward(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_weekly_room_reward_claims(uuid) TO authenticated, service_role;
