CREATE OR REPLACE FUNCTION public.refresh_bd_monthly_stats(p_staff_id uuid, p_period_yyyy_mm text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
DECLARE
  v_period text;
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
  v_bounds record;
  v_month_start date;
  v_month text;
BEGIN
  v_period := COALESCE(
    NULLIF(btrim(p_period_yyyy_mm), ''),
    public.get_period_id_for_ts(now())
  );

  IF v_period ~ '^\d{4}-\d{2}$' THEN
    IF to_char(public.policy_local_now(now()), 'YYYY-MM') = v_period THEN
      v_period := public.get_period_id_for_ts(now());
    ELSE
      v_period := v_period || '-M';
    END IF;
  END IF;

  IF v_period !~ '^\d{4}-\d{2}-[ABM]$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period; want YYYY-MM-A|B|M');
  END IF;

  SELECT * INTO v_staff FROM public.business_staff WHERE id = p_staff_id AND is_active;
  IF v_staff.id IS NULL OR public.normalize_staff_role(v_staff.role) <> 'bd' THEN
    RETURN json_build_object('success', false, 'message', 'BD staff not found');
  END IF;

  SELECT * INTO v_settings FROM public.bd_center_settings WHERE id = 1;
  SELECT * INTO v_bounds FROM public.get_period_bounds(v_period);
  v_month_start := make_date(
    split_part(v_period, '-', 1)::int,
    split_part(v_period, '-', 2)::int,
    1
  );
  v_month := substring(v_period from 1 for 7);

  v_in_window := (
    v_staff.created_at >= (
      v_month_start - make_interval(months => COALESCE(v_settings.new_bd_window_months, 3))
    )
  );

  IF right(v_period, 2) = '-M' THEN
    SELECT COALESCE(SUM(ca.total_usd + cb.total_usd), 0)
    INTO v_target
    FROM public.agencies a
    CROSS JOIN LATERAL public.calculate_agency_period_salary_per_host(a.id, v_month || '-A') ca
    CROSS JOIN LATERAL public.calculate_agency_period_salary_per_host(a.id, v_month || '-B') cb
    WHERE a.sponsor_staff_id = p_staff_id
      AND a.is_active = true
      AND a.owner_id IS DISTINCT FROM v_staff.user_id;
  ELSE
    SELECT COALESCE(SUM(c.total_usd), 0)
    INTO v_target
    FROM public.agencies a
    CROSS JOIN LATERAL public.calculate_agency_period_salary_per_host(a.id, v_period) c
    WHERE a.sponsor_staff_id = p_staff_id
      AND a.is_active = true
      AND a.owner_id IS DISTINCT FROM v_staff.user_id;
  END IF;

  SELECT COUNT(*) INTO v_new_agencies
  FROM public.agencies a
  WHERE a.sponsor_staff_id = p_staff_id
    AND a.owner_id IS DISTINCT FROM v_staff.user_id
    AND a.created_at::date BETWEEN v_bounds.start_date AND v_bounds.end_date;

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

CREATE OR REPLACE FUNCTION public.execute_one_bd_monthly_payout(p_period_yyyy_mm text, p_staff_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
DECLARE
  r public.business_staff%ROWTYPE;
  v_stats public.bd_staff_monthly_stats%ROWTYPE;
  v_total numeric;
  v_basic numeric;
  v_period text := btrim(p_period_yyyy_mm);
BEGIN
  IF v_period ~ '^\d{4}-\d{2}$' THEN
    v_period := v_period || '-M';
  END IF;
  IF v_period IS NULL OR v_period !~ '^\d{4}-\d{2}-[ABM]$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period; want YYYY-MM-A|B|M');
  END IF;
  IF p_staff_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'staff_id required');
  END IF;

  PERFORM pg_advisory_xact_lock(87201402, hashtext(v_period || ':' || p_staff_id::text));

  SELECT * INTO r
  FROM public.business_staff
  WHERE id = p_staff_id
    AND is_active
    AND public.normalize_staff_role(role) = 'bd';

  IF r.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'BD staff not found or inactive');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bd_staff_settlements
    WHERE staff_id = r.id AND period_yyyy_mm = v_period AND status = 'paid'
  ) THEN
    RETURN json_build_object(
      'success', true,
      'already_paid', true,
      'period', v_period,
      'staff_id', p_staff_id
    );
  END IF;

  PERFORM public.refresh_bd_monthly_stats(r.id, v_period);
  SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
  WHERE staff_id = r.id AND period_yyyy_mm = v_period;

  IF v_stats.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No BD stats for this period');
  END IF;

  v_total := COALESCE(v_stats.est_total_usd, 0);
  v_basic := COALESCE(v_stats.est_basic_usd, 0);

  IF v_total <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No payable BD salary for this period');
  END IF;

  UPDATE public.users
  SET cash_balance = COALESCE(cash_balance, 0) + v_total
  WHERE id = r.user_id;

  INSERT INTO public.bd_staff_settlements (
    staff_id, period_yyyy_mm, achieved_level,
    basic_usd, commission_usd, new_bd_usd, total_usd, status, paid_at
  ) VALUES (
    r.id, v_period, v_stats.achieved_level,
    v_basic,
    v_stats.est_commission_usd,
    v_stats.est_new_bd_usd,
    v_total, 'paid', now()
  )
  ON CONFLICT (staff_id, period_yyyy_mm) DO UPDATE SET
    achieved_level = EXCLUDED.achieved_level,
    basic_usd = EXCLUDED.basic_usd,
    commission_usd = EXCLUDED.commission_usd,
    new_bd_usd = EXCLUDED.new_bd_usd,
    total_usd = EXCLUDED.total_usd,
    status = 'paid',
    paid_at = now()
  WHERE public.bd_staff_settlements.status IS DISTINCT FROM 'paid';

  BEGIN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, description)
    VALUES (
      r.user_id,
      GREATEST(1, ROUND(v_total)::bigint),
      'cash',
      'salary_payout',
      format('BD period salary $%s for %s', v_total, v_period)
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN json_build_object(
    'success', true,
    'period', v_period,
    'staff_id', p_staff_id,
    'total_usd', v_total,
    'user_id', r.user_id
  );
END;
$function$;
