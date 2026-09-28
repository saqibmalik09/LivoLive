-- BD monthly target: sum of sponsored agencies' period salary estimates (A+B),
-- not host charm ÷ 68000. Level / package still from bd_level_configs.

CREATE OR REPLACE FUNCTION public.refresh_bd_monthly_stats(
  p_staff_id uuid,
  p_period_yyyy_mm text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  v_period text := COALESCE(p_period_yyyy_mm, to_char(current_date, 'YYYY-MM'));
  v_staff public.business_staff%ROWTYPE;
  v_target numeric := 0;
  v_level int := 0;
  v_cfg public.bd_level_configs%ROWTYPE;
  v_settings public.bd_center_settings%ROWTYPE;
  v_in_window boolean := false;
  v_basic numeric := 0;
  v_comm numeric := 0;
  v_new_bd numeric := 0;
  v_new_agencies int := 0;
  v_month_start date;
  v_month_end date;
BEGIN
  SELECT * INTO v_staff FROM public.business_staff WHERE id = p_staff_id AND is_active;
  IF v_staff.id IS NULL OR public.normalize_staff_role(v_staff.role) <> 'bd' THEN
    RETURN json_build_object('success', false, 'message', 'BD staff not found');
  END IF;

  SELECT * INTO v_settings FROM public.bd_center_settings WHERE id = 1;
  v_month_start := (v_period || '-01')::date;
  v_month_end := (date_trunc('month', v_month_start) + interval '1 month - 1 day')::date;

  v_in_window := (
    v_staff.created_at >= (
      v_month_start - make_interval(months => COALESCE(v_settings.new_bd_window_months, 3))
    )
  );

  -- Sum what each sponsored agency earns (per-host salary table) for both halves.
  SELECT COALESCE(SUM(agency_month_usd), 0)
  INTO v_target
  FROM (
    SELECT
      a.id AS agency_id,
      COALESCE((
        SELECT c.total_usd
        FROM public.calculate_agency_period_salary_per_host(a.id, v_period || '-A') c
      ), 0)
      + COALESCE((
        SELECT c.total_usd
        FROM public.calculate_agency_period_salary_per_host(a.id, v_period || '-B') c
      ), 0) AS agency_month_usd
    FROM public.agencies a
    WHERE a.sponsor_staff_id = p_staff_id
      AND a.is_active = true
      AND a.owner_id IS DISTINCT FROM v_staff.user_id
  ) s;

  SELECT COUNT(*) INTO v_new_agencies
  FROM public.agencies a
  WHERE a.sponsor_staff_id = p_staff_id
    AND a.owner_id IS DISTINCT FROM v_staff.user_id
    AND a.created_at::date BETWEEN v_month_start AND v_month_end;

  SELECT * INTO v_cfg
  FROM public.bd_level_configs
  WHERE is_active AND agency_target_usd <= COALESCE(v_target, 0)
  ORDER BY level DESC
  LIMIT 1;

  v_level := COALESCE(v_cfg.level, 0);
  v_comm := COALESCE(v_cfg.commission_usd, 0);
  v_new_bd := CASE
    WHEN v_in_window THEN COALESCE(v_cfg.new_bd_commission_usd, 0)
    ELSE 0
  END;
  v_basic := COALESCE(v_cfg.basic_salary_usd, 0);

  INSERT INTO public.bd_staff_monthly_stats AS s (
    staff_id, period_yyyy_mm, agency_target_usd, new_agencies, achieved_level,
    est_basic_usd, est_commission_usd, est_new_bd_usd, est_total_usd,
    in_new_bd_window, last_calculated_at
  ) VALUES (
    p_staff_id, v_period, COALESCE(v_target, 0), v_new_agencies, v_level,
    v_basic, v_comm, v_new_bd, v_basic + v_comm + v_new_bd, v_in_window, now()
  )
  ON CONFLICT (staff_id, period_yyyy_mm) DO UPDATE SET
    agency_target_usd = EXCLUDED.agency_target_usd,
    new_agencies = EXCLUDED.new_agencies,
    achieved_level = EXCLUDED.achieved_level,
    est_basic_usd = EXCLUDED.est_basic_usd,
    est_commission_usd = EXCLUDED.est_commission_usd,
    est_new_bd_usd = EXCLUDED.est_new_bd_usd,
    est_total_usd = EXCLUDED.est_total_usd,
    in_new_bd_window = EXCLUDED.in_new_bd_window,
    last_calculated_at = now();

  RETURN json_build_object(
    'success', true,
    'period', v_period,
    'agency_target_usd', COALESCE(v_target, 0),
    'achieved_level', v_level,
    'est_total_usd', v_basic + v_comm + v_new_bd
  );
END;
$function$;

ALTER FUNCTION public.refresh_bd_monthly_stats(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.refresh_bd_monthly_stats(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.refresh_bd_monthly_stats(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_bd_monthly_stats(uuid, text) TO service_role;
