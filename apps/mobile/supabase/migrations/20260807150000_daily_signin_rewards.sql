-- Daily Sign-in: configurable 7-day rewards + summary RPC.
-- Upgrades task_daily_checkin to grant coins or shop_item from config.
-- Keeps SK Live wheel-draw bump on successful check-in.

CREATE TABLE IF NOT EXISTS public.daily_signin_rewards (
  day_number    integer PRIMARY KEY CHECK (day_number BETWEEN 1 AND 7),
  reward_type   text NOT NULL CHECK (reward_type = ANY (ARRAY['coins'::text, 'shop_item'::text])),
  coin_amount   integer NOT NULL DEFAULT 0,
  shop_item_id  uuid REFERENCES public.shop_items(id) ON DELETE SET NULL,
  image_url     text,
  label         text,
  is_active     boolean NOT NULL DEFAULT true,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT daily_signin_rewards_coins_ok
    CHECK (reward_type <> 'coins' OR coin_amount > 0),
  CONSTRAINT daily_signin_rewards_item_ok
    CHECK (reward_type <> 'shop_item' OR shop_item_id IS NOT NULL)
);

ALTER TABLE public.daily_signin_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS daily_signin_rewards_select_all ON public.daily_signin_rewards;
CREATE POLICY daily_signin_rewards_select_all ON public.daily_signin_rewards
  FOR SELECT TO authenticated USING (true);

GRANT SELECT ON public.daily_signin_rewards TO authenticated;
GRANT ALL ON public.daily_signin_rewards TO service_role;

INSERT INTO public.daily_signin_rewards (day_number, reward_type, coin_amount, label, is_active)
VALUES
  (1, 'coins', 1000, 'Day 1 coins', true),
  (2, 'coins', 1500, 'Day 2 coins', true),
  (3, 'coins', 3000, 'Day 3 coins', true),
  (4, 'coins', 2000, 'Day 4 coins', true),
  (5, 'coins', 5000, 'Day 5 coins', true),
  (6, 'coins', 2500, 'Day 6 coins', true),
  (7, 'coins', 7000, 'Day 7 grand prize', true)
ON CONFLICT (day_number) DO NOTHING;

-- Ensure task_checkins exists (already in SK Live; IF NOT EXISTS for safety)
CREATE TABLE IF NOT EXISTS public.task_checkins (
  user_id           uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  streak_day        integer NOT NULL DEFAULT 0 CHECK (streak_day BETWEEN 0 AND 7),
  consecutive_days  integer NOT NULL DEFAULT 0,
  last_checkin_date date,
  updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.task_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS task_checkins_select_own ON public.task_checkins;
CREATE POLICY task_checkins_select_own ON public.task_checkins
  FOR SELECT TO authenticated USING (user_id = auth.uid());

GRANT SELECT ON public.task_checkins TO authenticated;
GRANT ALL ON public.task_checkins TO service_role;

UPDATE public.tasks SET is_active = false WHERE key = 'sign_in';

CREATE OR REPLACE FUNCTION public.get_daily_signin_summary()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_streak integer := 0;
  v_consecutive integer := 0;
  v_last date;
  v_checked_today boolean := false;
  v_today date := (now() AT TIME ZONE 'UTC')::date;
  v_days json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT streak_day, consecutive_days, last_checkin_date
  INTO v_streak, v_consecutive, v_last
  FROM public.task_checkins
  WHERE user_id = v_user_id;

  IF FOUND THEN
    v_checked_today := (v_last = v_today);
  ELSE
    v_streak := 0;
    v_consecutive := 0;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.day_number), '[]'::json)
  INTO v_days
  FROM (
    SELECT
      r.day_number,
      r.reward_type,
      r.coin_amount,
      r.shop_item_id,
      COALESCE(NULLIF(r.image_url, ''), si.image_url) AS image_url,
      COALESCE(NULLIF(r.label, ''), si.name, ('Day ' || r.day_number::text)) AS label,
      r.is_active,
      si.name AS shop_item_name,
      si.svga_url AS shop_item_svga
    FROM public.daily_signin_rewards r
    LEFT JOIN public.shop_items si ON si.id = r.shop_item_id
    WHERE r.is_active = true
  ) t;

  RETURN json_build_object(
    'success', true,
    'streak_day', COALESCE(v_streak, 0),
    'consecutive_days', COALESCE(v_consecutive, 0),
    'checked_today', v_checked_today,
    'days', v_days
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_daily_signin_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.task_daily_checkin()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.task_checkins%ROWTYPE;
  v_had_row boolean := false;
  v_today date := (now() AT TIME ZONE 'UTC')::date;
  v_next_day integer;
  v_consecutive integer;
  v_reward public.daily_signin_rewards%ROWTYPE;
  v_duration integer;
  v_expires timestamptz;
  v_item_name text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_row FROM public.task_checkins WHERE user_id = v_user_id FOR UPDATE;
  v_had_row := FOUND;

  IF v_had_row AND v_row.last_checkin_date = v_today THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Already signed in today',
      'streak_day', v_row.streak_day,
      'consecutive_days', v_row.consecutive_days,
      'checked_today', true
    );
  END IF;

  IF NOT v_had_row THEN
    v_next_day := 1;
    v_consecutive := 1;
  ELSIF v_row.last_checkin_date = v_today - 1 THEN
    v_next_day := CASE WHEN v_row.streak_day >= 7 THEN 1 ELSE v_row.streak_day + 1 END;
    v_consecutive := COALESCE(v_row.consecutive_days, 0) + 1;
  ELSE
    v_next_day := 1;
    v_consecutive := 1;
  END IF;

  SELECT * INTO v_reward
  FROM public.daily_signin_rewards
  WHERE day_number = v_next_day AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'No reward configured for this day');
  END IF;

  INSERT INTO public.task_checkins (user_id, streak_day, consecutive_days, last_checkin_date, updated_at)
  VALUES (v_user_id, v_next_day, v_consecutive, v_today, now())
  ON CONFLICT (user_id) DO UPDATE SET
    streak_day = EXCLUDED.streak_day,
    consecutive_days = EXCLUDED.consecutive_days,
    last_checkin_date = EXCLUDED.last_checkin_date,
    updated_at = now();

  -- Always grant a wheel draw on check-in (SK Live Task Center).
  UPDATE public.users
  SET task_wheel_draws = COALESCE(task_wheel_draws, 0) + 1
  WHERE id = v_user_id;

  IF v_reward.reward_type = 'coins' THEN
    UPDATE public.users
    SET coins = COALESCE(coins, 0) + v_reward.coin_amount
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id, v_reward.coin_amount, 'coin', 'task_checkin', v_user_id
    );

    RETURN json_build_object(
      'success', true,
      'streak_day', v_next_day,
      'consecutive_days', v_consecutive,
      'checked_today', true,
      'reward_type', 'coins',
      'coin_amount', v_reward.coin_amount,
      'reward', v_reward.coin_amount,
      'label', COALESCE(v_reward.label, 'Day ' || v_next_day::text),
      'message', 'Signed in! +' || v_reward.coin_amount::text || ' coins'
    );
  END IF;

  SELECT COALESCE(si.duration_days, 0), si.name
  INTO v_duration, v_item_name
  FROM public.shop_items si
  WHERE si.id = v_reward.shop_item_id AND si.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Shop item missing or inactive');
  END IF;

  v_expires := CASE
    WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
    ELSE '9999-12-31'::timestamptz
  END;

  INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
  VALUES (v_user_id, v_reward.shop_item_id, 'daily_signin', v_expires)
  ON CONFLICT (user_id, item_id) DO UPDATE SET
    expires_at = CASE
      WHEN user_inventory.expires_at IS NULL OR user_inventory.expires_at < now()
        THEN EXCLUDED.expires_at
      WHEN EXCLUDED.expires_at = '9999-12-31'::timestamptz
        THEN EXCLUDED.expires_at
      ELSE GREATEST(user_inventory.expires_at, EXCLUDED.expires_at)
    END,
    source = COALESCE(user_inventory.source, EXCLUDED.source);

  RETURN json_build_object(
    'success', true,
    'streak_day', v_next_day,
    'consecutive_days', v_consecutive,
    'checked_today', true,
    'reward_type', 'shop_item',
    'shop_item_id', v_reward.shop_item_id,
    'label', COALESCE(v_reward.label, v_item_name, 'Day ' || v_next_day::text),
    'message', 'Signed in! You got ' || COALESCE(v_item_name, 'an item')
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.task_daily_checkin() TO authenticated;

-- Sync Task Center day_rewards display with daily_signin_rewards config.
CREATE OR REPLACE FUNCTION public.get_task_center_summary()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_streak integer := 0;
  v_consec integer := 0;
  v_last date;
  v_draws integer := 0;
  v_checked boolean := false;
  v_spins json;
  v_tiers json;
  v_day_rewards integer[];
  v_today date := (now() AT TIME ZONE 'UTC')::date;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT COALESCE(task_wheel_draws, 0) INTO v_draws
  FROM public.users WHERE id = v_user_id;

  SELECT streak_day, consecutive_days, last_checkin_date
  INTO v_streak, v_consec, v_last
  FROM public.task_checkins WHERE user_id = v_user_id;

  v_streak := COALESCE(v_streak, 0);
  v_consec := COALESCE(v_consec, 0);
  v_checked := (v_last = v_today);

  IF v_last IS NOT NULL AND v_last < v_today - 1 THEN
    v_streak := 0;
    v_consec := 0;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
  INTO v_spins
  FROM (
    SELECT id, reward_label, reward_coins, created_at
    FROM public.task_wheel_spins
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 30
  ) t;

  SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.sort_order), '[]'::json)
  INTO v_tiers
  FROM (
    SELECT
      id,
      min_coins,
      max_coins,
      weight_percent,
      COALESCE(NULLIF(trim(label), ''), (min_coins::text || '-' || max_coins::text)) AS label,
      sort_order
    FROM public.task_wheel_tiers
    WHERE is_active = true
    ORDER BY sort_order, min_coins
  ) x;

  SELECT ARRAY(
    SELECT COALESCE(
      CASE
        WHEN r.reward_type = 'coins' THEN r.coin_amount
        ELSE 0
      END,
      0
    )
    FROM generate_series(1, 7) AS g(day_number)
    LEFT JOIN public.daily_signin_rewards r ON r.day_number = g.day_number AND r.is_active = true
    ORDER BY g.day_number
  ) INTO v_day_rewards;

  IF v_day_rewards IS NULL OR array_length(v_day_rewards, 1) IS NULL THEN
    v_day_rewards := ARRAY[1000, 1500, 3000, 2000, 5000, 2500, 7000];
  END IF;

  RETURN json_build_object(
    'success', true,
    'streak_day', v_streak,
    'consecutive_days', v_consec,
    'checked_today', v_checked,
    'wheel_draws', v_draws,
    'day_rewards', to_json(v_day_rewards),
    'spins', v_spins,
    'wheel_tiers', COALESCE(v_tiers, '[]'::json)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_task_center_summary() TO authenticated;
