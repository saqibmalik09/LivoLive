-- Task prize wheel: configurable coin ranges + percentage weights (admin-editable).

CREATE TABLE IF NOT EXISTS public.task_wheel_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  min_coins integer NOT NULL CHECK (min_coins >= 0),
  max_coins integer NOT NULL CHECK (max_coins >= 0),
  weight_percent numeric(6,2) NOT NULL CHECK (weight_percent > 0),
  label text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT task_wheel_tiers_range_chk CHECK (max_coins >= min_coins)
);

CREATE INDEX IF NOT EXISTS idx_task_wheel_tiers_active_sort
  ON public.task_wheel_tiers (is_active, sort_order);

-- Default: 100–1000 with percentage bands
INSERT INTO public.task_wheel_tiers (min_coins, max_coins, weight_percent, label, sort_order)
SELECT * FROM (VALUES
  (100, 300, 40.00::numeric, '100-300', 1),
  (301, 600, 35.00::numeric, '301-600', 2),
  (601, 1000, 25.00::numeric, '601-1K', 3)
) AS v(min_coins, max_coins, weight_percent, label, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.task_wheel_tiers LIMIT 1);

-- Pick coins from weighted tiers
CREATE OR REPLACE FUNCTION public._pick_task_wheel_reward()
RETURNS TABLE (out_label text, out_coins integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_total numeric := 0;
  v_roll numeric;
  v_running numeric := 0;
  v_min integer;
  v_max integer;
  v_label text;
  v_coins integer;
  r record;
BEGIN
  SELECT COALESCE(SUM(weight_percent), 0) INTO v_total
  FROM public.task_wheel_tiers
  WHERE is_active = true;

  IF v_total <= 0 THEN
    -- Fallback if no tiers configured
    out_label := '100';
    out_coins := 100;
    RETURN NEXT;
    RETURN;
  END IF;

  v_roll := random() * v_total;

  FOR r IN
    SELECT min_coins, max_coins, weight_percent, label, sort_order
    FROM public.task_wheel_tiers
    WHERE is_active = true
    ORDER BY sort_order, min_coins
  LOOP
    v_running := v_running + r.weight_percent;
    IF v_roll <= v_running THEN
      v_min := r.min_coins;
      v_max := r.max_coins;
      v_label := COALESCE(NULLIF(trim(r.label), ''), (r.min_coins::text || '-' || r.max_coins::text));
      EXIT;
    END IF;
  END LOOP;

  IF v_min IS NULL THEN
    SELECT min_coins, max_coins,
           COALESCE(NULLIF(trim(label), ''), (min_coins::text || '-' || max_coins::text))
    INTO v_min, v_max, v_label
    FROM public.task_wheel_tiers
    WHERE is_active = true
    ORDER BY sort_order DESC, min_coins DESC
    LIMIT 1;
  END IF;

  IF v_max <= v_min THEN
    v_coins := v_min;
  ELSE
    v_coins := v_min + floor(random() * (v_max - v_min + 1))::integer;
  END IF;

  out_label := v_label;
  out_coins := v_coins;
  RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.spin_task_wheel()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_draws integer;
  v_label text;
  v_coins integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT COALESCE(task_wheel_draws, 0) INTO v_draws
  FROM public.users WHERE id = v_user_id FOR UPDATE;

  IF v_draws <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No draws remaining');
  END IF;

  SELECT p.out_label, p.out_coins
  INTO v_label, v_coins
  FROM public._pick_task_wheel_reward() p
  LIMIT 1;

  IF v_coins IS NULL OR v_coins < 0 THEN
    RETURN json_build_object('success', false, 'message', 'Wheel config invalid');
  END IF;

  UPDATE public.users
  SET task_wheel_draws = task_wheel_draws - 1,
      coins = COALESCE(coins, 0) + v_coins
  WHERE id = v_user_id;

  INSERT INTO public.task_wheel_spins (user_id, reward_label, reward_coins)
  VALUES (v_user_id, v_label, v_coins);

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    v_user_id, v_coins, 'coin', 'task_wheel', v_user_id
  );

  RETURN json_build_object(
    'success', true,
    'label', v_label,
    'reward_coins', v_coins,
    'wheel_draws', (SELECT task_wheel_draws FROM public.users WHERE id = v_user_id)
  );
END;
$function$;

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

  RETURN json_build_object(
    'success', true,
    'streak_day', v_streak,
    'consecutive_days', v_consec,
    'checked_today', v_checked,
    'wheel_draws', v_draws,
    'day_rewards', to_json(ARRAY[10, 10, 15, 20, 20, 30, 50]),
    'spins', v_spins,
    'wheel_tiers', v_tiers
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.spin_task_wheel() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_task_center_summary() TO authenticated;

-- _pick_task_wheel_reward is internal; do not grant to clients

GRANT SELECT ON public.task_wheel_tiers TO authenticated;
ALTER TABLE public.task_wheel_tiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS task_wheel_tiers_select_all ON public.task_wheel_tiers;
CREATE POLICY task_wheel_tiers_select_all ON public.task_wheel_tiers
  FOR SELECT TO authenticated USING (true);
