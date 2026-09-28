-- BD valid work days: 15 → 10 (settings + levels + payout/audit thresholds).

UPDATE public.bd_center_settings
SET
  work_days_required = 10,
  updated_at = now()
WHERE id = 1;

UPDATE public.bd_level_configs
SET work_days = 10;

-- Bulk BD payout: attendance gate from settings
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
BEGIN
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
      WHERE staff_id = r.id AND period_yyyy_mm = p_period_yyyy_mm AND status = 'paid'
    ) THEN
      CONTINUE;
    END IF;

    PERFORM public.refresh_bd_monthly_stats(r.id, p_period_yyyy_mm);
    SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
    WHERE staff_id = r.id AND period_yyyy_mm = p_period_yyyy_mm;

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
      r.id, p_period_yyyy_mm, v_stats.achieved_level,
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

  RETURN json_build_object('success', true, 'period', p_period_yyyy_mm, 'bds_paid', v_paid);
END;
$function$;

-- Single BD payout
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
BEGIN
  IF p_period_yyyy_mm IS NULL OR p_period_yyyy_mm !~ '^\d{4}-\d{2}$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid period YYYY-MM');
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
  IF COALESCE(v_stats.work_days, 0) < v_req_days
     OR COALESCE(v_stats.work_hours, 0) < v_req_hours THEN
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

-- Admin audit: attendance gate from settings
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
BEGIN
  IF p_period_yyyy_mm IS NULL OR p_period_yyyy_mm !~ '^\d{4}-\d{2}$' THEN
    RAISE EXCEPTION 'Invalid period_yyyy_mm (want YYYY-MM)';
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
    WHERE s.period_yyyy_mm = p_period_yyyy_mm
  ),
  sett AS (
    SELECT x.*
    FROM public.bd_staff_settlements x
    WHERE x.period_yyyy_mm = p_period_yyyy_mm
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
    p_period_yyyy_mm::text,
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
