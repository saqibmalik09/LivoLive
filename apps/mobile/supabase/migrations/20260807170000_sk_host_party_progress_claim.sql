-- SK Host Party: live progress from host_period_stats + claim last period coins.

CREATE TABLE IF NOT EXISTS public.sk_host_party_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_event_id uuid NOT NULL REFERENCES public.party_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  period_id text NOT NULL,
  level integer NOT NULL CHECK (level >= 1),
  charms bigint NOT NULL DEFAULT 0,
  work_days integer NOT NULL DEFAULT 0,
  work_hours numeric(10, 1) NOT NULL DEFAULT 0,
  coin_reward bigint NOT NULL CHECK (coin_reward > 0),
  claimed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sk_host_party_claims_unique UNIQUE (party_event_id, user_id, period_id)
);

CREATE INDEX IF NOT EXISTS sk_host_party_claims_user_idx
  ON public.sk_host_party_claims (user_id, claimed_at DESC);

ALTER TABLE public.sk_host_party_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sk_host_party_claims_select_own ON public.sk_host_party_claims;
CREATE POLICY sk_host_party_claims_select_own ON public.sk_host_party_claims
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT ON public.sk_host_party_claims TO authenticated;
GRANT ALL ON public.sk_host_party_claims TO service_role;

-- Previous half-month period id (A → prior month B, B → same month A).
CREATE OR REPLACE FUNCTION public.get_previous_period_id(p_period_id text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_year int;
  v_month int;
  v_suffix text;
  v_prev date;
BEGIN
  v_year := split_part(p_period_id, '-', 1)::int;
  v_month := split_part(p_period_id, '-', 2)::int;
  v_suffix := split_part(p_period_id, '-', 3);

  IF v_suffix IN ('B', 'H2') THEN
    RETURN to_char(make_date(v_year, v_month, 1), 'YYYY-MM') || '-A';
  END IF;

  v_prev := (make_date(v_year, v_month, 1) - interval '1 day')::date;
  RETURN to_char(v_prev, 'YYYY-MM') || '-B';
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_previous_period_id(text) TO authenticated, service_role;

-- Count days in daily_seconds that meet min valid seconds.
CREATE OR REPLACE FUNCTION public.sk_host_count_valid_days(
  p_daily jsonb,
  p_min_seconds integer DEFAULT 7200
)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((
    SELECT COUNT(*)::integer
    FROM jsonb_each_text(COALESCE(p_daily, '{}'::jsonb)) e
    WHERE COALESCE(e.value::integer, 0) >= GREATEST(p_min_seconds, 1)
  ), 0);
$$;

GRANT EXECUTE ON FUNCTION public.sk_host_count_valid_days(jsonb, integer)
  TO authenticated, service_role;

-- Default LV1–25 charm ladder (mirrors mobile defaultSkHostTiers).
CREATE OR REPLACE FUNCTION public.sk_host_default_tiers()
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT jsonb_build_array(
    jsonb_build_object('level',1,'charms',500000,'coin_reward',50000,'days',7,'hours',14),
    jsonb_build_object('level',2,'charms',1000000,'coin_reward',100000,'days',7,'hours',14),
    jsonb_build_object('level',3,'charms',2000000,'coin_reward',200000,'days',7,'hours',14),
    jsonb_build_object('level',4,'charms',3500000,'coin_reward',350000,'days',7,'hours',14),
    jsonb_build_object('level',5,'charms',5000000,'coin_reward',500000,'days',7,'hours',14),
    jsonb_build_object('level',6,'charms',8000000,'coin_reward',800000,'days',7,'hours',14),
    jsonb_build_object('level',7,'charms',12000000,'coin_reward',1200000,'days',7,'hours',14),
    jsonb_build_object('level',8,'charms',18000000,'coin_reward',1800000,'days',7,'hours',14),
    jsonb_build_object('level',9,'charms',25000000,'coin_reward',2500000,'days',7,'hours',14),
    jsonb_build_object('level',10,'charms',35000000,'coin_reward',3500000,'days',7,'hours',14),
    jsonb_build_object('level',11,'charms',50000000,'coin_reward',5000000,'days',7,'hours',14),
    jsonb_build_object('level',12,'charms',70000000,'coin_reward',7000000,'days',7,'hours',14),
    jsonb_build_object('level',13,'charms',100000000,'coin_reward',10000000,'days',7,'hours',14),
    jsonb_build_object('level',14,'charms',140000000,'coin_reward',12000000,'days',7,'hours',14),
    jsonb_build_object('level',15,'charms',200000000,'coin_reward',14000000,'days',7,'hours',14),
    jsonb_build_object('level',16,'charms',280000000,'coin_reward',16000000,'days',7,'hours',14),
    jsonb_build_object('level',17,'charms',400000000,'coin_reward',18000000,'days',7,'hours',14),
    jsonb_build_object('level',18,'charms',550000000,'coin_reward',20000000,'days',7,'hours',14),
    jsonb_build_object('level',19,'charms',750000000,'coin_reward',22000000,'days',7,'hours',14),
    jsonb_build_object('level',20,'charms',1000000000,'coin_reward',24000000,'days',7,'hours',14),
    jsonb_build_object('level',21,'charms',1300000000,'coin_reward',25500000,'days',7,'hours',14),
    jsonb_build_object('level',22,'charms',1700000000,'coin_reward',27000000,'days',7,'hours',14),
    jsonb_build_object('level',23,'charms',2200000000,'coin_reward',28000000,'days',7,'hours',14),
    jsonb_build_object('level',24,'charms',2600000000,'coin_reward',29000000,'days',7,'hours',14),
    jsonb_build_object('level',25,'charms',3000000000,'coin_reward',30000000,'days',7,'hours',14)
  );
$$;

CREATE OR REPLACE FUNCTION public.sk_host_tiers_from_config(p_config jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_raw jsonb;
BEGIN
  v_raw := COALESCE(p_config -> 'reward_tiers', p_config -> 'host_tiers');
  IF v_raw IS NULL OR jsonb_typeof(v_raw) <> 'array' OR jsonb_array_length(v_raw) = 0 THEN
    RETURN public.sk_host_default_tiers();
  END IF;
  RETURN v_raw;
END;
$$;

-- Highest completed level (0 = none).
CREATE OR REPLACE FUNCTION public.sk_host_match_level(
  p_tiers jsonb,
  p_charms bigint,
  p_work_days integer,
  p_work_hours numeric
)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_item jsonb;
  v_level int := 0;
  v_t_level int;
  v_t_charms bigint;
  v_t_days int;
  v_t_hours numeric;
BEGIN
  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(p_tiers, '[]'::jsonb))
    ORDER BY COALESCE((value->>'level')::int, 0)
  LOOP
    v_t_level := COALESCE((v_item->>'level')::int, 0);
    v_t_charms := COALESCE((v_item->>'charms')::bigint, 0);
    v_t_days := COALESCE((v_item->>'days')::int, 7);
    v_t_hours := COALESCE((v_item->>'hours')::numeric, 14);
    IF p_charms >= v_t_charms
       AND p_work_days >= v_t_days
       AND p_work_hours >= v_t_hours THEN
      v_level := v_t_level;
    ELSE
      EXIT;
    END IF;
  END LOOP;
  RETURN v_level;
END;
$$;

CREATE OR REPLACE FUNCTION public.sk_host_tier_coin_reward(p_tiers jsonb, p_level integer)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((
    SELECT COALESCE((t.value->>'coin_reward')::bigint, (t.value->>'coins')::bigint, 0)
    FROM jsonb_array_elements(COALESCE(p_tiers, '[]'::jsonb)) WITH ORDINALITY AS t(value, ord)
    WHERE COALESCE((t.value->>'level')::int, 0) = p_level
    ORDER BY t.ord
    LIMIT 1
  ), 0);
$$;

CREATE OR REPLACE FUNCTION public.sk_host_read_stats(
  p_user_id uuid,
  p_period_id text,
  OUT o_charms bigint,
  OUT o_work_days integer,
  OUT o_work_hours numeric,
  OUT o_on_mic_seconds integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_row public.host_period_stats%ROWTYPE;
  v_min int := 7200;
BEGIN
  o_charms := 0;
  o_work_days := 0;
  o_work_hours := 0;
  o_on_mic_seconds := 0;

  SELECT COALESCE(min_valid_day_seconds, 7200)
  INTO v_min
  FROM public.salary_chain_configs
  WHERE id = 1;

  SELECT * INTO v_row
  FROM public.host_period_stats
  WHERE user_id = p_user_id AND period_id = p_period_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  o_charms := COALESCE(v_row.charm_points, 0);
  o_on_mic_seconds := COALESCE(v_row.total_on_mic_seconds, 0);
  o_work_hours := ROUND((o_on_mic_seconds::numeric / 3600.0), 1);
  o_work_days := public.sk_host_count_valid_days(v_row.daily_seconds, v_min);
  -- Fallback if daily_seconds empty but valid_days tracked.
  IF o_work_days = 0 AND COALESCE(v_row.valid_days, 0) > 0 THEN
    o_work_days := v_row.valid_days;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sk_host_read_stats(uuid, text) TO authenticated, service_role;

-- Live progress for current + last period claim status.
CREATE OR REPLACE FUNCTION public.get_my_sk_host_progress(p_event_id uuid)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_event public.party_events%ROWTYPE;
  v_tiers jsonb;
  v_curr text;
  v_prev text;
  v_curr_b record;
  v_prev_b record;
  v_charms bigint;
  v_days int;
  v_hours numeric;
  v_secs int;
  v_level int;
  v_next jsonb;
  v_l_charms bigint;
  v_l_days int;
  v_l_hours numeric;
  v_l_secs int;
  v_l_level int;
  v_l_coins bigint;
  v_claimed boolean;
  v_claim_open boolean;
  v_local_today date;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_event
  FROM public.party_events
  WHERE id = p_event_id;

  IF NOT FOUND OR v_event.event_kind <> 'sk_host_native' THEN
    RETURN json_build_object('success', false, 'message', 'Event not found');
  END IF;

  v_tiers := public.sk_host_tiers_from_config(COALESCE(v_event.action_config, '{}'::jsonb));

  v_curr := public.get_period_id_for_ts(now());
  PERFORM public.ensure_salary_period(v_curr);
  v_prev := public.get_previous_period_id(v_curr);
  PERFORM public.ensure_salary_period(v_prev);

  SELECT * INTO v_curr_b FROM public.get_period_bounds(v_curr);
  SELECT * INTO v_prev_b FROM public.get_period_bounds(v_prev);

  SELECT * INTO v_charms, v_days, v_hours, v_secs
  FROM public.sk_host_read_stats(v_uid, v_curr);

  v_level := public.sk_host_match_level(v_tiers, v_charms, v_days, v_hours);

  SELECT t.value INTO v_next
  FROM jsonb_array_elements(v_tiers) WITH ORDINALITY AS t(value, ord)
  WHERE COALESCE((t.value->>'level')::int, 0) = v_level + 1
  ORDER BY t.ord
  LIMIT 1;

  SELECT * INTO v_l_charms, v_l_days, v_l_hours, v_l_secs
  FROM public.sk_host_read_stats(v_uid, v_prev);

  v_l_level := public.sk_host_match_level(v_tiers, v_l_charms, v_l_days, v_l_hours);
  v_l_coins := CASE
    WHEN v_l_level > 0 THEN public.sk_host_tier_coin_reward(v_tiers, v_l_level)
    ELSE 0
  END;

  v_claimed := EXISTS (
    SELECT 1 FROM public.sk_host_party_claims c
    WHERE c.party_event_id = p_event_id
      AND c.user_id = v_uid
      AND c.period_id = v_prev
  );

  v_local_today := public.policy_local_now(now())::date;
  -- Claim opens the day after previous period ends, through end of current period.
  v_claim_open := (v_local_today > v_prev_b.end_date)
    AND (v_local_today <= v_curr_b.end_date)
    AND (NOT v_claimed)
    AND (v_l_coins > 0);

  RETURN json_build_object(
    'success', true,
    'event_id', p_event_id,
    'period_id', v_curr,
    'period_start', v_curr_b.start_date,
    'period_end', v_curr_b.end_date,
    'period_end_at', (v_curr_b.end_date::text || ' 23:59:59')::timestamp,
    'charms', v_charms,
    'work_days', v_days,
    'work_hours', v_hours,
    'on_mic_seconds', v_secs,
    'level', v_level,
    'next_tier', v_next,
    'last_period_id', v_prev,
    'last_period_start', v_prev_b.start_date,
    'last_period_end', v_prev_b.end_date,
    'last_charms', v_l_charms,
    'last_work_days', v_l_days,
    'last_work_hours', v_l_hours,
    'last_level', v_l_level,
    'last_coin_reward', v_l_coins,
    'last_claimed', v_claimed,
    'can_claim', v_claim_open,
    'tiers', v_tiers,
    'rules', COALESCE(v_event.action_config->>'rules', '')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_sk_host_progress(uuid) TO authenticated, service_role;

-- Claim coins for previous period highest unlocked level.
CREATE OR REPLACE FUNCTION public.claim_sk_host_party_reward(p_event_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_event public.party_events%ROWTYPE;
  v_tiers jsonb;
  v_curr text;
  v_prev text;
  v_curr_b record;
  v_prev_b record;
  v_charms bigint;
  v_days int;
  v_hours numeric;
  v_secs int;
  v_level int;
  v_coins bigint;
  v_claim_id uuid;
  v_local_today date;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_event
  FROM public.party_events
  WHERE id = p_event_id;

  IF NOT FOUND OR v_event.event_kind <> 'sk_host_native' THEN
    RETURN json_build_object('success', false, 'message', 'Event not found');
  END IF;

  v_tiers := public.sk_host_tiers_from_config(COALESCE(v_event.action_config, '{}'::jsonb));
  v_curr := public.get_period_id_for_ts(now());
  v_prev := public.get_previous_period_id(v_curr);
  PERFORM public.ensure_salary_period(v_prev);

  SELECT * INTO v_curr_b FROM public.get_period_bounds(v_curr);
  SELECT * INTO v_prev_b FROM public.get_period_bounds(v_prev);

  v_local_today := public.policy_local_now(now())::date;
  IF v_local_today <= v_prev_b.end_date THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Rewards unlock after the last activity period ends'
    );
  END IF;

  IF v_local_today > v_curr_b.end_date THEN
    RETURN json_build_object('success', false, 'message', 'Claim window expired');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.sk_host_party_claims c
    WHERE c.party_event_id = p_event_id
      AND c.user_id = v_uid
      AND c.period_id = v_prev
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed for last period');
  END IF;

  SELECT * INTO v_charms, v_days, v_hours, v_secs
  FROM public.sk_host_read_stats(v_uid, v_prev);

  v_level := public.sk_host_match_level(v_tiers, v_charms, v_days, v_hours);
  IF v_level < 1 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Last period target not reached',
      'charms', v_charms,
      'work_days', v_days,
      'work_hours', v_hours
    );
  END IF;

  v_coins := public.sk_host_tier_coin_reward(v_tiers, v_level);
  IF v_coins <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No coin reward for this level');
  END IF;

  UPDATE public.users
  SET coins = coins + v_coins
  WHERE id = v_uid;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id, description
  ) VALUES (
    v_uid,
    v_coins,
    'coin',
    'sk_host_party_reward',
    p_event_id,
    'SK Host Party reward ' || v_prev || ' LV' || v_level::text
  );

  INSERT INTO public.sk_host_party_claims (
    party_event_id, user_id, period_id, level,
    charms, work_days, work_hours, coin_reward
  ) VALUES (
    p_event_id, v_uid, v_prev, v_level,
    v_charms, v_days, v_hours, v_coins
  )
  RETURNING id INTO v_claim_id;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'period_id', v_prev,
    'level', v_level,
    'coin_amount', v_coins,
    'charms', v_charms,
    'work_days', v_days,
    'work_hours', v_hours
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  WHEN others THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_sk_host_party_reward(uuid) TO authenticated, service_role;
