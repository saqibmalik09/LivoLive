-- Mic Daily Rewards: duration tiers (e.g. 30m / 1h) with coins or shop assets.
-- Any unmuted seated user accrues seconds per UTC+3 day; each tier claimable once/day.

CREATE TABLE IF NOT EXISTS public.mic_daily_reward_levels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  required_seconds integer NOT NULL CHECK (required_seconds > 0),
  sort_order integer NOT NULL DEFAULT 0,
  reward_type text NOT NULL DEFAULT 'coins'
    CHECK (reward_type IN ('coins', 'shop_item')),
  coin_amount integer NOT NULL DEFAULT 0 CHECK (coin_amount >= 0),
  shop_item_id uuid REFERENCES public.shop_items (id) ON DELETE SET NULL,
  duration_days integer NULL CHECK (duration_days IS NULL OR duration_days >= 0),
  title text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS mic_daily_reward_levels_active_idx
  ON public.mic_daily_reward_levels (is_active, sort_order, required_seconds);

CREATE TABLE IF NOT EXISTS public.mic_daily_reward_rules (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  rules jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_mic_daily_progress (
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  period_key text NOT NULL,
  seconds integer NOT NULL DEFAULT 0 CHECK (seconds >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, period_key)
);

CREATE TABLE IF NOT EXISTS public.mic_daily_reward_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  level_id uuid NOT NULL REFERENCES public.mic_daily_reward_levels (id) ON DELETE CASCADE,
  period_key text NOT NULL,
  reward_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, level_id, period_key)
);

CREATE INDEX IF NOT EXISTS mic_daily_reward_claims_user_period_idx
  ON public.mic_daily_reward_claims (user_id, period_key, created_at DESC);

INSERT INTO public.mic_daily_reward_rules (id, rules)
VALUES (
  1,
  '[
    "Sit on a mic seat with your mic unmuted to earn daily mic time.",
    "Progress resets every day at 00:00 (UTC+3).",
    "Each unlocked reward tier can be claimed once per day.",
    "Rewards may be coins or timed inventory items configured by the platform."
  ]'::jsonb
)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.mic_daily_reward_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mic_daily_reward_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_mic_daily_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mic_daily_reward_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mic_daily_reward_levels_read ON public.mic_daily_reward_levels;
CREATE POLICY mic_daily_reward_levels_read ON public.mic_daily_reward_levels
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS mic_daily_reward_rules_read ON public.mic_daily_reward_rules;
CREATE POLICY mic_daily_reward_rules_read ON public.mic_daily_reward_rules
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS user_mic_daily_progress_read_own ON public.user_mic_daily_progress;
CREATE POLICY user_mic_daily_progress_read_own ON public.user_mic_daily_progress
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS mic_daily_reward_claims_read_own ON public.mic_daily_reward_claims;
CREATE POLICY mic_daily_reward_claims_read_own ON public.mic_daily_reward_claims
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.report_user_mic_activity(p_is_on_mic boolean)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_period text;
  v_seconds integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF NOT COALESCE(p_is_on_mic, false) THEN
    RETURN json_build_object('success', true, 'skipped', 'not_on_mic');
  END IF;

  SELECT d.period_key INTO v_period
  FROM public.room_reward_day_bounds(now()) d;

  INSERT INTO public.user_mic_daily_progress (user_id, period_key, seconds, updated_at)
  VALUES (v_user_id, v_period, 60, now())
  ON CONFLICT (user_id, period_key) DO UPDATE
    SET seconds = public.user_mic_daily_progress.seconds + 60,
        updated_at = now()
  RETURNING seconds INTO v_seconds;

  RETURN json_build_object(
    'success', true,
    'period_key', v_period,
    'seconds', v_seconds
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_mic_daily_reward_progress()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_period text;
  v_seconds integer := 0;
  v_remaining bigint := 0;
  v_day_end timestamptz;
  v_levels json;
  v_rules json;
  v_claimed uuid[];
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT d.period_key, d.seconds_remaining, d.day_end
  INTO v_period, v_remaining, v_day_end
  FROM public.room_reward_day_bounds(now()) d;

  SELECT COALESCE(p.seconds, 0)
  INTO v_seconds
  FROM public.user_mic_daily_progress p
  WHERE p.user_id = v_user_id
    AND p.period_key = v_period;

  SELECT COALESCE(array_agg(c.level_id), '{}')
  INTO v_claimed
  FROM public.mic_daily_reward_claims c
  WHERE c.user_id = v_user_id
    AND c.period_key = v_period;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.sort_order, t.required_seconds), '[]'::json)
  INTO v_levels
  FROM (
    SELECT
      l.id,
      l.required_seconds,
      l.sort_order,
      l.reward_type,
      l.coin_amount,
      l.shop_item_id,
      l.duration_days,
      l.title,
      l.image_url,
      l.is_active,
      (l.id = ANY (v_claimed)) AS claimed,
      (
        l.is_active
        AND v_seconds >= l.required_seconds
        AND NOT (l.id = ANY (v_claimed))
      ) AS can_claim
    FROM public.mic_daily_reward_levels l
    WHERE l.is_active = true
  ) t;

  SELECT COALESCE(r.rules, '[]'::jsonb)::json
  INTO v_rules
  FROM public.mic_daily_reward_rules r
  WHERE r.id = 1;

  RETURN json_build_object(
    'success', true,
    'seconds', COALESCE(v_seconds, 0),
    'period_key', v_period,
    'seconds_remaining', v_remaining,
    'resets_at', v_day_end,
    'levels', COALESCE(v_levels, '[]'::json),
    'rules', COALESCE(v_rules, '[]'::json)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.claim_mic_daily_reward(p_level_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_period text;
  v_seconds integer := 0;
  v_level public.mic_daily_reward_levels%ROWTYPE;
  v_duration integer;
  v_expires timestamptz;
  v_snapshot jsonb;
  v_claim_id uuid;
  v_title text;
  v_image_url text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_level_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid level');
  END IF;

  SELECT d.period_key INTO v_period
  FROM public.room_reward_day_bounds(now()) d;

  SELECT * INTO v_level
  FROM public.mic_daily_reward_levels l
  WHERE l.id = p_level_id
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.mic_daily_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.level_id = p_level_id
      AND c.period_key = v_period
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed today');
  END IF;

  SELECT COALESCE(p.seconds, 0)
  INTO v_seconds
  FROM public.user_mic_daily_progress p
  WHERE p.user_id = v_user_id
    AND p.period_key = v_period;

  IF COALESCE(v_seconds, 0) < v_level.required_seconds THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Not enough mic time',
      'seconds', COALESCE(v_seconds, 0),
      'required', v_level.required_seconds
    );
  END IF;

  v_title := COALESCE(NULLIF(trim(v_level.title), ''), '');
  v_image_url := COALESCE(v_level.image_url, '');

  v_snapshot := jsonb_build_object(
    'level_id', v_level.id,
    'required_seconds', v_level.required_seconds,
    'reward_type', v_level.reward_type,
    'coin_amount', v_level.coin_amount,
    'shop_item_id', v_level.shop_item_id,
    'title', v_title,
    'image_url', v_image_url,
    'period_key', v_period
  );

  IF v_level.reward_type = 'coins' AND v_level.coin_amount > 0 THEN
    UPDATE public.users
    SET coins = coins + v_level.coin_amount
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id,
      v_level.coin_amount,
      'coin',
      'room_reward',
      v_user_id
    );
  ELSIF v_level.reward_type = 'shop_item' AND v_level.shop_item_id IS NOT NULL THEN
    SELECT COALESCE(v_level.duration_days, si.duration_days, 0),
           CASE WHEN v_title = '' THEN COALESCE(si.name, 'Reward') ELSE v_title END,
           CASE WHEN v_image_url = '' THEN COALESCE(si.image_url, '') ELSE v_image_url END
    INTO v_duration, v_title, v_image_url
    FROM public.shop_items si
    WHERE si.id = v_level.shop_item_id
      AND si.is_active = true;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Shop item missing');
    END IF;

    v_expires := CASE
      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
      ELSE '9999-12-31'::timestamptz
    END;

    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
    VALUES (v_user_id, v_level.shop_item_id, 'mic_daily_reward', v_expires)
    ON CONFLICT (user_id, item_id) DO UPDATE
      SET expires_at = GREATEST(public.user_inventory.expires_at, EXCLUDED.expires_at),
          source = COALESCE(public.user_inventory.source, EXCLUDED.source);

    v_snapshot := v_snapshot || jsonb_build_object(
      'title', v_title,
      'image_url', v_image_url,
      'duration_days', v_duration,
      'expires_at', v_expires
    );
  ELSE
    RETURN json_build_object('success', false, 'message', 'No reward configured');
  END IF;

  INSERT INTO public.mic_daily_reward_claims (
    user_id, level_id, period_key, reward_snapshot
  ) VALUES (
    v_user_id, p_level_id, v_period, v_snapshot
  )
  RETURNING id INTO v_claim_id;

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
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_mic_daily_reward_claims()
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
      c.level_id,
      c.period_key,
      c.reward_snapshot,
      c.created_at
    FROM public.mic_daily_reward_claims c
    WHERE c.user_id = v_user_id
    LIMIT 100
  ) t;

  RETURN json_build_object('success', true, 'claims', v_rows);
END;
$function$;

GRANT SELECT ON public.mic_daily_reward_levels TO anon, authenticated, service_role;
GRANT SELECT ON public.mic_daily_reward_rules TO anon, authenticated, service_role;
GRANT SELECT ON public.user_mic_daily_progress TO authenticated, service_role;
GRANT SELECT ON public.mic_daily_reward_claims TO authenticated, service_role;
GRANT ALL ON public.mic_daily_reward_levels TO service_role;
GRANT ALL ON public.mic_daily_reward_rules TO service_role;
GRANT ALL ON public.user_mic_daily_progress TO service_role;
GRANT ALL ON public.mic_daily_reward_claims TO service_role;

GRANT EXECUTE ON FUNCTION public.report_user_mic_activity(boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_mic_daily_reward_progress() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_mic_daily_reward(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_mic_daily_reward_claims() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
