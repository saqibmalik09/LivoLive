-- BD salary periods = agency style A/B (1–15 / 16–end), PK local clock.
-- Target = sum of sponsored agency salaries for THAT half only.

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
BEGIN
  v_period := COALESCE(
    NULLIF(btrim(p_period_yyyy_mm), ''),
    public.get_period_id_for_ts(now())
  );

  -- Legacy YYYY-MM → current half of that month (prefer B if today in B of same month)
  IF v_period ~ '^\d{4}-\d{2}$' THEN
    IF to_char(public.policy_local_now(now()), 'YYYY-MM') = v_period THEN
      v_period := public.get_period_id_for_ts(now());
    ELSE
      v_period := v_period || '-B';
    END IF;
  END IF;

  IF v_period !~ '^\d{4}-\d{2}-[AB]$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period; want YYYY-MM-A|B');
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

  v_in_window := (
    v_staff.created_at >= (
      v_month_start - make_interval(months => COALESCE(v_settings.new_bd_window_months, 3))
    )
  );

  -- Sum agency salary estimates for this half only (same formula as agency payout)
  SELECT COALESCE(SUM(c.total_usd), 0)
  INTO v_target
  FROM public.agencies a
  CROSS JOIN LATERAL public.calculate_agency_period_salary_per_host(a.id, v_period) c
  WHERE a.sponsor_staff_id = p_staff_id
    AND a.is_active = true
    AND a.owner_id IS DISTINCT FROM v_staff.user_id;

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

CREATE OR REPLACE FUNCTION public.run_scheduled_bd_period_payouts()
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
    v_res := public.execute_bd_monthly_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_16_period_a', 'period', v_period, 'result', v_res);
  END IF;

  IF v_day = 1 THEN
    v_prev := (date_trunc('month', v_local::date) - interval '1 day')::date;
    v_period := to_char(v_prev, 'YYYY-MM') || '-B';
    v_res := public.execute_bd_monthly_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_1_prev_period_b', 'period', v_period, 'result', v_res);
  END IF;

  RETURN json_build_object('ran', false, 'reason', 'not_payout_day', 'local_day', v_day);
END;
$function$;

-- Keep old name as alias → new A/B scheduler (no more “only day 15 monthly”)
CREATE OR REPLACE FUNCTION public.run_scheduled_bd_monthly_payout()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
BEGIN
  RETURN public.run_scheduled_bd_period_payouts();
END;
$function$;

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
  v_req_days int := 10;
  v_req_hours numeric := 30;
  v_period text := btrim(p_period_yyyy_mm);
BEGIN
  IF v_period ~ '^\d{4}-\d{2}$' THEN
    v_period := v_period || '-B';
  END IF;
  IF v_period IS NULL OR v_period !~ '^\d{4}-\d{2}-[AB]$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period; want YYYY-MM-A|B');
  END IF;

  SELECT
    COALESCE(work_days_required, 10),
    COALESCE(work_hours_required, 30)
  INTO v_req_days, v_req_hours
  FROM public.bd_center_settings
  WHERE id = 1;

  FOR r IN
    SELECT * FROM public.business_staff
    WHERE is_active AND public.normalize_staff_role(role) = 'bd'
  LOOP
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
    IF COALESCE(v_stats.work_days, 0) < v_req_days
       OR COALESCE(v_stats.work_hours, 0) < v_req_hours THEN
      v_total := COALESCE(v_stats.est_commission_usd, 0) + COALESCE(v_stats.est_new_bd_usd, 0);
    END IF;

    IF v_total <= 0 THEN CONTINUE; END IF;

    UPDATE public.users
    SET cash_balance = COALESCE(cash_balance, 0) + v_total
    WHERE id = r.user_id;

    INSERT INTO public.bd_staff_settlements (
      staff_id, period_yyyy_mm, achieved_level,
      basic_usd, commission_usd, new_bd_usd, total_usd, status, paid_at
    ) VALUES (
      r.id, v_period, v_stats.achieved_level,
      CASE
        WHEN COALESCE(v_stats.work_days, 0) >= v_req_days
         AND COALESCE(v_stats.work_hours, 0) >= v_req_hours
        THEN v_stats.est_basic_usd
        ELSE 0
      END,
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
      paid_at = now();

    v_paid := v_paid + 1;
  END LOOP;

  RETURN json_build_object('success', true, 'period', v_period, 'bds_paid', v_paid);
END;
$function$;

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
  v_req_days int := 10;
  v_req_hours numeric := 30;
  v_period text := btrim(p_period_yyyy_mm);
BEGIN
  IF v_period ~ '^\d{4}-\d{2}$' THEN
    v_period := v_period || '-B';
  END IF;
  IF v_period IS NULL OR v_period !~ '^\d{4}-\d{2}-[AB]$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period; want YYYY-MM-A|B');
  END IF;
  IF p_staff_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'staff_id required');
  END IF;

  SELECT
    COALESCE(work_days_required, 10),
    COALESCE(work_hours_required, 30)
  INTO v_req_days, v_req_hours
  FROM public.bd_center_settings
  WHERE id = 1;

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
  IF COALESCE(v_stats.work_days, 0) < v_req_days
     OR COALESCE(v_stats.work_hours, 0) < v_req_hours THEN
    v_total := COALESCE(v_stats.est_commission_usd, 0) + COALESCE(v_stats.est_new_bd_usd, 0);
    v_basic := 0;
  ELSE
    v_basic := COALESCE(v_stats.est_basic_usd, 0);
  END IF;

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

ALTER FUNCTION public.execute_one_bd_monthly_payout(text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.execute_one_bd_monthly_payout(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_one_bd_monthly_payout(text, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.get_my_bd_center(p_period_yyyy_mm text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff public.business_staff%ROWTYPE;
  v_period text := COALESCE(NULLIF(btrim(p_period_yyyy_mm), ''), public.get_period_id_for_ts(now()));
  v_stats public.bd_staff_monthly_stats%ROWTYPE;
  v_settings public.bd_center_settings%ROWTYPE;
  v_next public.bd_level_configs%ROWTYPE;
  v_agencies json;
  v_gift_packs json;
  v_bounds record;
  v_payout_date date;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF v_period ~ '^\d{4}-\d{2}$' THEN
    IF to_char(public.policy_local_now(now()), 'YYYY-MM') = v_period THEN
      v_period := public.get_period_id_for_ts(now());
    ELSE
      v_period := v_period || '-B';
    END IF;
  END IF;

  SELECT * INTO v_staff FROM public.business_staff
  WHERE user_id = v_uid AND is_active = true
  ORDER BY created_at DESC LIMIT 1;

  IF v_staff.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No staff role');
  END IF;

  IF public.normalize_staff_role(v_staff.role) = 'bd' THEN
    PERFORM public.refresh_bd_monthly_stats(v_staff.id, v_period);
  END IF;

  SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
  WHERE staff_id = v_staff.id AND period_yyyy_mm = v_period;

  SELECT * INTO v_settings FROM public.bd_center_settings WHERE id = 1;
  SELECT * INTO v_bounds FROM public.get_period_bounds(v_period);
  v_payout_date := v_bounds.payout_date;

  SELECT * INTO v_next FROM public.bd_level_configs
  WHERE is_active AND level > COALESCE(v_stats.achieved_level, 0)
  ORDER BY level ASC LIMIT 1;

  SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) INTO v_agencies
  FROM (
    SELECT id, name, agency_code, is_active, owner_id, created_at
    FROM public.agencies
    WHERE sponsor_staff_id = v_staff.id AND is_active = true
      AND owner_id IS DISTINCT FROM v_staff.user_id
    ORDER BY created_at DESC
  ) a;

  v_gift_packs := public.get_bd_gift_packs();

  RETURN json_build_object(
    'success', true,
    'staff', json_build_object(
      'id', v_staff.id,
      'role', public.normalize_staff_role(v_staff.role),
      'staff_code', v_staff.staff_code
    ),
    'period', v_period,
    'settlement_day', EXTRACT(DAY FROM v_payout_date)::int,
    'payout_date', v_payout_date,
    'timezone', COALESCE(v_settings.timezone, 'UTC+5'),
    'stats', CASE WHEN v_stats.id IS NULL THEN NULL ELSE json_build_object(
      'agency_target_usd', v_stats.agency_target_usd,
      'achieved_level', v_stats.achieved_level,
      'est_basic_usd', v_stats.est_basic_usd,
      'est_commission_usd', v_stats.est_commission_usd,
      'est_new_bd_usd', v_stats.est_new_bd_usd,
      'est_total_usd', v_stats.est_total_usd,
      'new_agencies', v_stats.new_agencies,
      'in_new_bd_window', v_stats.in_new_bd_window,
      'work_days', v_stats.work_days,
      'work_hours', v_stats.work_hours
    ) END,
    'next_level', CASE WHEN v_next.level IS NULL THEN NULL ELSE json_build_object(
      'level', v_next.level,
      'agency_target_usd', v_next.agency_target_usd,
      'remaining_usd', GREATEST(v_next.agency_target_usd - COALESCE(v_stats.agency_target_usd, 0), 0)
    ) END,
    'agencies', v_agencies,
    'levels', (SELECT COALESCE(json_agg(row_to_json(l) ORDER BY l.level), '[]'::json) FROM public.bd_level_configs l WHERE l.is_active),
    'gift_packs', v_gift_packs
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_bd_month_audit(p_period_yyyy_mm text)
RETURNS TABLE (
  staff_id uuid,
  user_id uuid,
  username text,
  short_id bigint,
  staff_code text,
  role text,
  is_active boolean,
  period_yyyy_mm text,
  agency_target_usd numeric,
  work_days int,
  work_hours numeric,
  new_agencies int,
  achieved_level int,
  est_basic_usd numeric,
  est_commission_usd numeric,
  est_new_bd_usd numeric,
  est_total_usd numeric,
  payable_usd numeric,
  basic_qualifies boolean,
  in_new_bd_window boolean,
  last_calculated_at timestamptz,
  settlement_status text,
  settlement_total_usd numeric,
  settlement_basic_usd numeric,
  settlement_commission_usd numeric,
  settlement_new_bd_usd numeric,
  paid_at timestamptz,
  cash_balance numeric,
  pending_withdraw_usd numeric,
  completed_withdraw_usd numeric,
  implied_cash_usd numeric,
  flag_unpaid_with_due boolean,
  flag_over_withdraw boolean,
  flag_no_attendance boolean,
  flag_ok boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_period text := btrim(p_period_yyyy_mm);
BEGIN
  IF v_period ~ '^\d{4}-\d{2}$' THEN
    v_period := v_period || '-B';
  END IF;
  IF v_period IS NULL OR v_period !~ '^\d{4}-\d{2}-[AB]$' THEN
    RAISE EXCEPTION 'Invalid period (want YYYY-MM-A|B)';
  END IF;

  RETURN QUERY
  WITH req AS (
    SELECT
      COALESCE(s.work_days_required, 10)::int AS days,
      COALESCE(s.work_hours_required, 30)::numeric AS hours
    FROM public.bd_center_settings s
    WHERE s.id = 1
  ),
  bds AS (
    SELECT
      bs.id AS staff_id,
      bs.user_id,
      bs.staff_code,
      bs.role,
      bs.is_active
    FROM public.business_staff bs
    WHERE public.normalize_staff_role(bs.role) = 'bd'
  ),
  stats AS (
    SELECT s.*
    FROM public.bd_staff_monthly_stats s
    WHERE s.period_yyyy_mm = v_period
  ),
  sett AS (
    SELECT x.*
    FROM public.bd_staff_settlements x
    WHERE x.period_yyyy_mm = v_period
  ),
  wd AS (
    SELECT
      w.user_id,
      coalesce(sum(w.amount) FILTER (WHERE w.status = 'pending'), 0)::numeric AS pending_usd,
      coalesce(sum(w.amount) FILTER (
        WHERE w.status IN ('approved', 'completed', 'paid')
      ), 0)::numeric AS completed_usd
    FROM public.wallet_withdrawals w
    WHERE w.user_id IN (SELECT bds.user_id FROM bds)
    GROUP BY w.user_id
  )
  SELECT
    b.staff_id,
    b.user_id,
    coalesce(u.username, 'User')::text,
    u.short_id::bigint,
    b.staff_code::text,
    b.role::text,
    coalesce(b.is_active, false),
    v_period::text,
    coalesce(st.agency_target_usd, 0)::numeric,
    coalesce(st.work_days, 0)::int,
    coalesce(st.work_hours, 0)::numeric,
    coalesce(st.new_agencies, 0)::int,
    coalesce(st.achieved_level, 0)::int,
    coalesce(st.est_basic_usd, 0)::numeric,
    coalesce(st.est_commission_usd, 0)::numeric,
    coalesce(st.est_new_bd_usd, 0)::numeric,
    coalesce(st.est_total_usd, 0)::numeric,
    (
      CASE
        WHEN coalesce(st.work_days, 0) >= req.days AND coalesce(st.work_hours, 0) >= req.hours
          THEN coalesce(st.est_total_usd, 0)
        ELSE coalesce(st.est_commission_usd, 0) + coalesce(st.est_new_bd_usd, 0)
      END
    )::numeric AS payable_usd,
    (coalesce(st.work_days, 0) >= req.days AND coalesce(st.work_hours, 0) >= req.hours) AS basic_qualifies,
    coalesce(st.in_new_bd_window, false),
    st.last_calculated_at,
    se.status::text AS settlement_status,
    coalesce(se.total_usd, 0)::numeric AS settlement_total_usd,
    coalesce(se.basic_usd, 0)::numeric AS settlement_basic_usd,
    coalesce(se.commission_usd, 0)::numeric AS settlement_commission_usd,
    coalesce(se.new_bd_usd, 0)::numeric AS settlement_new_bd_usd,
    se.paid_at,
    coalesce(u.cash_balance, 0)::numeric,
    coalesce(w.pending_usd, 0)::numeric,
    coalesce(w.completed_usd, 0)::numeric,
    (coalesce(u.cash_balance, 0) + coalesce(w.pending_usd, 0))::numeric AS implied_cash_usd,
    (
      (
        CASE
          WHEN coalesce(st.work_days, 0) >= req.days AND coalesce(st.work_hours, 0) >= req.hours
            THEN coalesce(st.est_total_usd, 0)
          ELSE coalesce(st.est_commission_usd, 0) + coalesce(st.est_new_bd_usd, 0)
        END
      ) > 0.01
      AND coalesce(se.status, '') IS DISTINCT FROM 'paid'
    ) AS flag_unpaid_with_due,
    (
      coalesce(se.status, '') = 'paid'
      AND coalesce(w.pending_usd, 0) > coalesce(se.total_usd, 0) + 0.01
    ) AS flag_over_withdraw,
    (
      coalesce(st.work_days, 0) < req.days OR coalesce(st.work_hours, 0) < req.hours
    ) AS flag_no_attendance,
    (
      NOT (
        (
          CASE
            WHEN coalesce(st.work_days, 0) >= req.days AND coalesce(st.work_hours, 0) >= req.hours
              THEN coalesce(st.est_total_usd, 0)
            ELSE coalesce(st.est_commission_usd, 0) + coalesce(st.est_new_bd_usd, 0)
          END
        ) > 0.01
        AND coalesce(se.status, '') IS DISTINCT FROM 'paid'
      )
      AND NOT (
        coalesce(se.status, '') = 'paid'
        AND coalesce(w.pending_usd, 0) > coalesce(se.total_usd, 0) + 0.01
      )
    ) AS flag_ok
  FROM bds b
  CROSS JOIN req
  JOIN public.users u ON u.id = b.user_id
  LEFT JOIN stats st ON st.staff_id = b.staff_id
  LEFT JOIN sett se ON se.staff_id = b.staff_id
  LEFT JOIN wd w ON w.user_id = b.user_id
  ORDER BY
    coalesce(b.is_active, false) DESC,
    (
      CASE
        WHEN coalesce(st.work_days, 0) >= req.days AND coalesce(st.work_hours, 0) >= req.hours
          THEN coalesce(st.est_total_usd, 0)
        ELSE coalesce(st.est_commission_usd, 0) + coalesce(st.est_new_bd_usd, 0)
      END
    ) DESC,
    u.short_id NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_bd_month_audit(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bd_month_audit(text) TO service_role;

-- Cron: one daily BD check (same cadence as agency), not 15th-only
DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname IN (
      'bd-monthly-payout-15th',
      'bd-payout-daily-check'
    )
       OR lower(command) LIKE '%run_scheduled_bd_monthly_payout%'
       OR lower(command) LIKE '%run_scheduled_bd_period_payouts%';

    -- PK 00:10 = 19:10 UTC (5 min after agency 00:05)
    PERFORM cron.schedule(
      'bd-payout-daily-check',
      '10 19 * * *',
      'SELECT public.run_scheduled_bd_period_payouts();'
    );
  END IF;
END;
$cron$;
