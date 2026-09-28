-- Polish: staff cosmetics, BD-only agency apply, midnight period gate, auto payouts

-- =============================================================================
-- 1. Staff role cosmetics (Assistant / CS tag + frame)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.staff_role_cosmetics (
  role text PRIMARY KEY CHECK (role IN ('assistant', 'customer_service')),
  frame_shop_item_id uuid REFERENCES public.shop_items(id) ON DELETE SET NULL,
  tag_shop_item_id uuid REFERENCES public.shop_items(id) ON DELETE SET NULL,
  duration_days int,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.staff_role_cosmetics (role)
VALUES ('assistant'), ('customer_service')
ON CONFLICT (role) DO NOTHING;

ALTER TABLE public.staff_role_cosmetics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read staff role cosmetics" ON public.staff_role_cosmetics;
CREATE POLICY "Public read staff role cosmetics"
  ON public.staff_role_cosmetics FOR SELECT TO public USING (true);

CREATE OR REPLACE FUNCTION public.grant_staff_role_cosmetics(
  p_user_id uuid,
  p_role text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_role text := public.normalize_staff_role(p_role);
  v_cfg public.staff_role_cosmetics%ROWTYPE;
  v_item uuid;
  v_expires timestamptz;
  v_granted int := 0;
BEGIN
  IF v_role NOT IN ('assistant', 'customer_service') THEN
    RETURN json_build_object('success', false, 'message', 'Role has no cosmetics');
  END IF;

  SELECT * INTO v_cfg FROM public.staff_role_cosmetics WHERE role = v_role;
  IF v_cfg.role IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Cosmetics not configured');
  END IF;

  IF v_cfg.duration_days IS NULL THEN
    v_expires := '9999-12-31T00:00:00Z'::timestamptz;
  ELSE
    v_expires := now() + make_interval(days => v_cfg.duration_days);
  END IF;

  FOREACH v_item IN ARRAY ARRAY[v_cfg.frame_shop_item_id, v_cfg.tag_shop_item_id]
  LOOP
    IF v_item IS NULL THEN CONTINUE; END IF;
    IF EXISTS (
      SELECT 1 FROM public.user_inventory
      WHERE user_id = p_user_id AND item_id = v_item
    ) THEN
      CONTINUE;
    END IF;
    INSERT INTO public.user_inventory (user_id, item_id, is_equipped, expires_at)
    VALUES (p_user_id, v_item, false, v_expires);
    v_granted := v_granted + 1;
  END LOOP;

  RETURN json_build_object('success', true, 'granted', v_granted, 'role', v_role);
END;
$function$;

CREATE OR REPLACE FUNCTION public.backfill_staff_role_cosmetics(p_role text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  r record;
  v_total int := 0;
  v_res json;
BEGIN
  FOR r IN
    SELECT user_id, role FROM public.business_staff
    WHERE is_active = true
      AND public.normalize_staff_role(role) IN ('assistant', 'customer_service')
      AND (p_role IS NULL OR public.normalize_staff_role(role) = public.normalize_staff_role(p_role))
  LOOP
    v_res := public.grant_staff_role_cosmetics(r.user_id, r.role);
    IF (v_res->>'success')::boolean THEN
      v_total := v_total + COALESCE((v_res->>'granted')::int, 0);
    END IF;
  END LOOP;
  RETURN json_build_object('success', true, 'items_granted', v_total);
END;
$function$;

-- Patch create_business_staff to grant cosmetics after insert
CREATE OR REPLACE FUNCTION public.create_business_staff(
  p_target_user_id uuid,
  p_role text,
  p_parent_staff_id uuid DEFAULT NULL,
  p_created_by_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_parent public.business_staff%ROWTYPE;
  v_role text := public.normalize_staff_role(p_role);
  v_parent_role text;
  v_new_id uuid;
  v_code text;
  v_count int;
BEGIN
  IF v_role NOT IN ('super_bd', 'county_admin', 'bd', 'assistant', 'customer_service') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid role');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.business_staff
    WHERE user_id = p_target_user_id AND is_active = true
  ) THEN
    RETURN json_build_object('success', false, 'message', 'User already has an active staff role');
  END IF;

  IF v_role = 'super_bd' THEN
    IF p_parent_staff_id IS NOT NULL THEN
      RETURN json_build_object('success', false, 'message', 'Super Admin cannot have a parent staff');
    END IF;
  ELSE
    IF p_parent_staff_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Parent staff is required');
    END IF;

    SELECT * INTO v_parent
    FROM public.business_staff
    WHERE id = p_parent_staff_id AND is_active = true;

    IF v_parent.id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Parent staff not found');
    END IF;

    v_parent_role := public.normalize_staff_role(v_parent.role);

    IF v_parent_role = 'super_bd' THEN
      IF v_role NOT IN ('county_admin', 'assistant', 'customer_service') THEN
        RETURN json_build_object('success', false, 'message', 'Super Admin can only create County Admin, Assistant, or Customer Service');
      END IF;
      SELECT COUNT(*) INTO v_count FROM public.business_staff
      WHERE parent_staff_id = v_parent.id AND is_active = true AND public.normalize_staff_role(role) = v_role;
      IF v_role = 'county_admin' AND v_count >= 2 THEN
        RETURN json_build_object('success', false, 'message', 'Max 2 County Admins per Super Admin');
      END IF;
      IF v_role = 'assistant' AND v_count >= 2 THEN
        RETURN json_build_object('success', false, 'message', 'Max 2 Assistants per Super Admin');
      END IF;
      IF v_role = 'customer_service' AND v_count >= 4 THEN
        RETURN json_build_object('success', false, 'message', 'Max 4 Customer Service per Super Admin');
      END IF;
    ELSIF v_parent_role = 'county_admin' THEN
      IF v_role <> 'bd' THEN
        RETURN json_build_object('success', false, 'message', 'County Admin can only create BD');
      END IF;
    ELSE
      RETURN json_build_object('success', false, 'message', 'This role cannot create staff');
    END IF;
  END IF;

  v_code := public.generate_staff_code();

  INSERT INTO public.business_staff (user_id, role, parent_staff_id, staff_code, created_by_user_id)
  VALUES (p_target_user_id, v_role, p_parent_staff_id, v_code, p_created_by_user_id)
  RETURNING id INTO v_new_id;

  IF v_role IN ('assistant', 'customer_service') THEN
    PERFORM public.grant_staff_role_cosmetics(p_target_user_id, v_role);
  END IF;

  RETURN json_build_object(
    'success', true,
    'staff_id', v_new_id,
    'staff_code', v_code,
    'role', v_role
  );
END;
$function$;

-- =============================================================================
-- 2. BD-only agency application RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.submit_agency_application(
  p_real_name text,
  p_whatsapp text,
  p_bd_staff_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_bd public.business_staff%ROWTYPE;
  v_app_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF trim(COALESCE(p_bd_staff_code, '')) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Enter a valid BD ID');
  END IF;

  IF trim(COALESCE(p_real_name, '')) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Real name is required');
  END IF;

  SELECT * INTO v_bd
  FROM public.business_staff
  WHERE staff_code = trim(p_bd_staff_code)
    AND is_active = true;

  IF v_bd.id IS NULL OR public.normalize_staff_role(v_bd.role) <> 'bd' THEN
    RETURN json_build_object('success', false, 'message', 'Enter a valid BD ID');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_applications
    WHERE user_id = v_uid AND type = 'agency' AND status = 'pending'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'You have already applied!');
  END IF;

  INSERT INTO public.user_applications (
    user_id, type, real_name, whatsapp_number, target_staff_id, status
  ) VALUES (
    v_uid, 'agency', trim(p_real_name), trim(COALESCE(p_whatsapp, '')), v_bd.id, 'pending'
  )
  RETURNING id INTO v_app_id;

  RETURN json_build_object('success', true, 'application_id', v_app_id);
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'You have already applied!');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_agency_application(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_staff_role_cosmetics(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.backfill_staff_role_cosmetics(text) TO authenticated;

-- =============================================================================
-- 3. Period gate: day 1-15 = A, day 16+ = B (midnight / local calendar)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.policy_local_now(p_ts timestamptz DEFAULT now())
RETURNS timestamp
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_tz text := 'UTC+3';
  v_offset interval := interval '3 hours';
BEGIN
  SELECT COALESCE(timezone, 'UTC+3') INTO v_tz FROM public.bd_center_settings WHERE id = 1;
  IF v_tz ~ '^[Uu][Tt][Cc]([+-]\d{1,2})$' THEN
    v_offset := (substring(v_tz from '[+-]\d{1,2}') || ' hours')::interval;
  ELSIF v_tz ~ '^[+-]\d{1,2}$' THEN
    v_offset := (v_tz || ' hours')::interval;
  END IF;
  RETURN (p_ts AT TIME ZONE 'UTC') + v_offset;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_period_id_for_ts(p_ts timestamptz DEFAULT now())
RETURNS text
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_local timestamp;
  v_day int;
BEGIN
  v_local := public.policy_local_now(p_ts);
  v_day := EXTRACT(DAY FROM v_local)::int;
  IF v_day <= 15 THEN
    RETURN to_char(v_local, 'YYYY-MM') || '-A';
  END IF;
  RETURN to_char(v_local, 'YYYY-MM') || '-B';
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_period_id_for_date(p_date date DEFAULT current_date)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_local_today date := public.policy_local_now(now())::date;
BEGIN
  -- Live clock for "today" so midnight boundary is correct for gifts/stats
  IF p_date = v_local_today OR p_date = CURRENT_DATE THEN
    RETURN public.get_period_id_for_ts(now());
  END IF;
  -- Historical calendar day at local noon
  RETURN public.get_period_id_for_ts(
    ((p_date::text || ' 12:00:00')::timestamp - interval '3 hours') AT TIME ZONE 'UTC'
  );
END;
$function$;

-- Keep get_current_period_info on live clock
CREATE OR REPLACE FUNCTION public.get_current_period_info()
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_period_id text;
  b record;
BEGIN
  v_period_id := public.get_period_id_for_ts(now());
  PERFORM public.ensure_salary_period(v_period_id);
  SELECT * INTO b FROM public.get_period_bounds(v_period_id);
  RETURN json_build_object(
    'period_id', v_period_id,
    'start_date', b.start_date,
    'end_date', b.end_date,
    'payout_date', b.payout_date
  );
END;
$function$;

-- =============================================================================
-- 4. Scheduled agency + BD payouts
-- =============================================================================

CREATE OR REPLACE FUNCTION public.run_scheduled_agency_period_payouts()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_local timestamp := public.policy_local_now(now());
  v_day int := EXTRACT(DAY FROM v_local)::int;
  v_period text;
  v_prev date;
  v_res json;
BEGIN
  IF v_day = 16 THEN
    v_period := to_char(v_local, 'YYYY-MM') || '-A';
    PERFORM public.ensure_salary_period(v_period);
    v_res := public.execute_agency_period_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_16_period_a', 'result', v_res);
  END IF;

  IF v_day = 1 THEN
    v_prev := (date_trunc('month', v_local::date) - interval '1 day')::date;
    v_period := to_char(v_prev, 'YYYY-MM') || '-B';
    PERFORM public.ensure_salary_period(v_period);
    v_res := public.execute_agency_period_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_1_prev_period_b', 'result', v_res);
  END IF;

  RETURN json_build_object('ran', false, 'reason', 'not_payout_day', 'local_day', v_day);
END;
$function$;

CREATE OR REPLACE FUNCTION public.run_scheduled_bd_monthly_payout()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_local timestamp := public.policy_local_now(now());
  v_day int := EXTRACT(DAY FROM v_local)::int;
  v_prev_month text;
  v_res json;
BEGIN
  IF v_day <> 15 THEN
    RETURN json_build_object('ran', false, 'reason', 'not_bd_pay_day');
  END IF;

  v_prev_month := to_char((date_trunc('month', v_local::date) - interval '1 day')::date, 'YYYY-MM');
  v_res := public.execute_bd_monthly_payout(v_prev_month);
  RETURN json_build_object('ran', true, 'period', v_prev_month, 'result', v_res);
END;
$function$;

DO $outer$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;

  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname IN (
    'agency-payout-period-a',
    'agency-payout-period-b',
    'bd-monthly-payout-15th'
  );

  -- UTC+3 00:05 = UTC previous day 21:05
  PERFORM cron.schedule(
    'agency-payout-period-a',
    '5 21 15 * *',
    $$SELECT public.run_scheduled_agency_period_payouts();$$
  );

  PERFORM cron.schedule(
    'agency-payout-period-b',
    '5 21 28-31 * *',
    $$SELECT public.run_scheduled_agency_period_payouts();$$
  );

  -- Also fire explicitly on 1st UTC+3 (= 21:05 on last day of prev month UTC for most months)
  -- Wrapper no-ops unless local day is 1 or 16, so daily check near midnight is safer:
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'agency-payout-daily-check';
  PERFORM cron.schedule(
    'agency-payout-daily-check',
    '5 21 * * *',
    $$SELECT public.run_scheduled_agency_period_payouts();$$
  );

  PERFORM cron.schedule(
    'bd-monthly-payout-15th',
    '10 21 14 * *',
    $$SELECT public.run_scheduled_bd_monthly_payout();$$
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END;
$outer$;
