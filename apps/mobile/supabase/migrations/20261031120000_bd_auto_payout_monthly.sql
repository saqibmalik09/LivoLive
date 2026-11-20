CREATE OR REPLACE FUNCTION public.execute_bd_monthly_payout(p_period_yyyy_mm text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  r record;
  v_stats public.bd_staff_monthly_stats%ROWTYPE;
  v_paid int := 0;
  v_total numeric;
  v_basic numeric;
  v_rows int;
  v_period text := btrim(p_period_yyyy_mm);
BEGIN
  IF v_period ~ '^\d{4}-\d{2}$' THEN
    v_period := v_period || '-M';
  END IF;
  IF v_period IS NULL OR v_period !~ '^\d{4}-\d{2}-[ABM]$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period; want YYYY-MM-A|B|M');
  END IF;

  FOR r IN
    SELECT * FROM public.business_staff
    WHERE is_active AND public.normalize_staff_role(role) = 'bd'
  LOOP
    PERFORM pg_advisory_xact_lock(87201402, hashtext(v_period || ':' || r.id::text));

    IF EXISTS (
      SELECT 1 FROM public.bd_staff_settlements
      WHERE staff_id = r.id AND period_yyyy_mm = v_period AND status = 'paid'
    ) THEN
      CONTINUE;
    END IF;

    PERFORM public.refresh_bd_monthly_stats(r.id, v_period);
    SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
    WHERE staff_id = r.id AND period_yyyy_mm = v_period;

    IF v_stats.id IS NULL THEN CONTINUE; END IF;

    v_total := COALESCE(v_stats.est_total_usd, 0);
    v_basic := COALESCE(v_stats.est_basic_usd, 0);

    IF v_total <= 0 THEN CONTINUE; END IF;

    INSERT INTO public.bd_staff_settlements (
      staff_id, period_yyyy_mm, achieved_level,
      basic_usd, commission_usd, new_bd_usd, total_usd, status, paid_at
    ) VALUES (
      r.id, v_period, v_stats.achieved_level,
      v_basic, v_stats.est_commission_usd, v_stats.est_new_bd_usd,
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

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      CONTINUE;
    END IF;

    UPDATE public.users
    SET cash_balance = COALESCE(cash_balance, 0) + v_total
    WHERE id = r.user_id;

    BEGIN
      INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, description)
      VALUES (
        r.user_id,
        GREATEST(1, ROUND(v_total)::bigint),
        'cash',
        'salary_payout',
        format('BD monthly salary $%s for %s', v_total, v_period)
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    v_paid := v_paid + 1;
  END LOOP;

  RETURN json_build_object('success', true, 'period', v_period, 'bds_paid', v_paid);
END;
$function$;

CREATE OR REPLACE FUNCTION public.run_scheduled_bd_period_payouts()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_local timestamp := public.policy_local_now(now());
  v_day int := EXTRACT(DAY FROM v_local)::int;
  v_prev date;
  v_period text;
  v_res json;
BEGIN
  IF v_day = 1 THEN
    v_prev := (date_trunc('month', v_local::date) - interval '1 day')::date;
    v_period := to_char(v_prev, 'YYYY-MM') || '-M';
    v_res := public.execute_bd_monthly_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_1_prev_month_monthly', 'period', v_period, 'result', v_res);
  END IF;

  RETURN json_build_object('ran', false, 'reason', 'not_payout_day', 'local_day', v_day);
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
  v_rows int;
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
    RETURN json_build_object('success', true, 'already_paid', true, 'period', v_period, 'staff_id', p_staff_id);
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

  INSERT INTO public.bd_staff_settlements (
    staff_id, period_yyyy_mm, achieved_level,
    basic_usd, commission_usd, new_bd_usd, total_usd, status, paid_at
  ) VALUES (
    r.id, v_period, v_stats.achieved_level,
    v_basic, v_stats.est_commission_usd, v_stats.est_new_bd_usd,
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

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RETURN json_build_object('success', true, 'already_paid', true, 'period', v_period, 'staff_id', p_staff_id);
  END IF;

  UPDATE public.users
  SET cash_balance = COALESCE(cash_balance, 0) + v_total
  WHERE id = r.user_id;

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
