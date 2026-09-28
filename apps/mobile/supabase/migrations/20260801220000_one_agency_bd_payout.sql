-- Per-entity Agency / BD USD payout (Salary Hub & Audit cards).

CREATE OR REPLACE FUNCTION public.execute_one_agency_period_payout(
  p_period_id text,
  p_agency_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  r record;
  v_matched public.agency_salary_level_configs%ROWTYPE;
  v_total_charm bigint;
  v_charm_usd numeric;
  v_agent_usd numeric;
  v_sum numeric;
  v_owner uuid;
  v_credited numeric;
BEGIN
  IF p_period_id IS NULL OR length(trim(p_period_id)) = 0 THEN
    RETURN json_build_object('success', false, 'message', 'period_id required');
  END IF;
  IF p_agency_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'agency_id required');
  END IF;

  PERFORM pg_advisory_xact_lock(87201401, hashtext(p_period_id || ':' || p_agency_id::text));

  SELECT id, owner_id INTO r
  FROM public.agencies
  WHERE id = p_agency_id AND is_active = true AND owner_id IS NOT NULL;

  IF r.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Agency not found or inactive');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.agency_period_settlements
    WHERE agency_id = r.id AND period_id = p_period_id AND status = 'paid'
  ) THEN
    RETURN json_build_object('success', true, 'already_paid', true, 'period_id', p_period_id, 'agency_id', p_agency_id);
  END IF;

  SELECT COALESCE(SUM(hps.charm_points), 0) INTO v_total_charm
  FROM public.agency_members am
  JOIN public.host_period_stats hps
    ON hps.user_id = am.user_id AND hps.period_id = p_period_id
  WHERE am.agency_id = r.id;

  SELECT * INTO v_matched FROM public.match_agency_salary_level(v_total_charm);
  v_charm_usd := COALESCE(v_matched.charm_salary_usd, 0);
  v_agent_usd := COALESCE(v_matched.agent_salary_usd, 0);
  v_sum := v_charm_usd + v_agent_usd;

  IF v_sum <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No payable agency salary for this period');
  END IF;

  INSERT INTO public.agency_period_settlements (
    agency_id, period_id, total_charm, achieved_level,
    charm_salary_usd, agent_salary_usd, total_usd, owner_user_id, status, paid_at
  ) VALUES (
    r.id, p_period_id, v_total_charm, COALESCE(v_matched.level, 0),
    v_charm_usd, v_agent_usd, v_sum, r.owner_id, 'paid', now()
  )
  ON CONFLICT (agency_id, period_id) DO UPDATE SET
    total_charm = EXCLUDED.total_charm,
    achieved_level = EXCLUDED.achieved_level,
    charm_salary_usd = EXCLUDED.charm_salary_usd,
    agent_salary_usd = EXCLUDED.agent_salary_usd,
    total_usd = EXCLUDED.total_usd,
    owner_user_id = EXCLUDED.owner_user_id,
    status = 'paid',
    paid_at = now()
  WHERE public.agency_period_settlements.status IS DISTINCT FROM 'paid'
  RETURNING owner_user_id, total_usd INTO v_owner, v_credited;

  IF v_owner IS NULL THEN
    RETURN json_build_object('success', true, 'already_paid', true, 'period_id', p_period_id, 'agency_id', p_agency_id);
  END IF;

  UPDATE public.users
  SET cash_balance = COALESCE(cash_balance, 0) + v_credited
  WHERE id = v_owner;

  BEGIN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, description)
    VALUES (
      v_owner,
      GREATEST(1, ROUND(v_credited)::bigint),
      'cash',
      'salary_payout',
      format('Agency period salary $%s for %s', v_credited, p_period_id)
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN json_build_object(
    'success', true,
    'period_id', p_period_id,
    'agency_id', p_agency_id,
    'total_usd', v_credited,
    'owner_user_id', v_owner
  );
END;
$function$;

ALTER FUNCTION public.execute_one_agency_period_payout(text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.execute_one_agency_period_payout(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_one_agency_period_payout(text, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.execute_one_bd_monthly_payout(
  p_period_yyyy_mm text,
  p_staff_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  r public.business_staff%ROWTYPE;
  v_stats public.bd_staff_monthly_stats%ROWTYPE;
  v_total numeric;
  v_basic numeric;
BEGIN
  IF p_period_yyyy_mm IS NULL OR p_period_yyyy_mm !~ '^\d{4}-\d{2}$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period YYYY-MM');
  END IF;
  IF p_staff_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'staff_id required');
  END IF;

  PERFORM pg_advisory_xact_lock(87201402, hashtext(p_period_yyyy_mm || ':' || p_staff_id::text));

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
    WHERE staff_id = r.id AND period_yyyy_mm = p_period_yyyy_mm AND status = 'paid'
  ) THEN
    RETURN json_build_object(
      'success', true,
      'already_paid', true,
      'period', p_period_yyyy_mm,
      'staff_id', p_staff_id
    );
  END IF;

  PERFORM public.refresh_bd_monthly_stats(r.id, p_period_yyyy_mm);
  SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
  WHERE staff_id = r.id AND period_yyyy_mm = p_period_yyyy_mm;

  IF v_stats.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No BD stats for this month');
  END IF;

  v_total := COALESCE(v_stats.est_total_usd, 0);
  IF COALESCE(v_stats.work_days, 0) < 15 OR COALESCE(v_stats.work_hours, 0) < 30 THEN
    v_total := COALESCE(v_stats.est_commission_usd, 0) + COALESCE(v_stats.est_new_bd_usd, 0);
    v_basic := 0;
  ELSE
    v_basic := COALESCE(v_stats.est_basic_usd, 0);
  END IF;

  IF v_total <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No payable BD salary for this month');
  END IF;

  UPDATE public.users
  SET cash_balance = COALESCE(cash_balance, 0) + v_total
  WHERE id = r.user_id;

  INSERT INTO public.bd_staff_settlements (
    staff_id, period_yyyy_mm, achieved_level,
    basic_usd, commission_usd, new_bd_usd, total_usd, status, paid_at
  ) VALUES (
    r.id, p_period_yyyy_mm, v_stats.achieved_level,
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
      format('BD monthly salary $%s for %s', v_total, p_period_yyyy_mm)
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN json_build_object(
    'success', true,
    'period', p_period_yyyy_mm,
    'staff_id', p_staff_id,
    'total_usd', v_total,
    'user_id', r.user_id
  );
END;
$function$;

ALTER FUNCTION public.execute_one_bd_monthly_payout(text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.execute_one_bd_monthly_payout(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_one_bd_monthly_payout(text, uuid) TO service_role;
