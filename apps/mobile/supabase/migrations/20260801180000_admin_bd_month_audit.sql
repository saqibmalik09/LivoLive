-- BD monthly audit: estimates, attendance, settlement, cash / withdraw flags.

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
  WITH bds AS (
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
        WHEN coalesce(st.work_days, 0) >= 15 AND coalesce(st.work_hours, 0) >= 30
          THEN coalesce(st.est_total_usd, 0)
        ELSE coalesce(st.est_commission_usd, 0) + coalesce(st.est_new_bd_usd, 0)
      END
    )::numeric AS payable_usd,
    (coalesce(st.work_days, 0) >= 15 AND coalesce(st.work_hours, 0) >= 30) AS basic_qualifies,
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
          WHEN coalesce(st.work_days, 0) >= 15 AND coalesce(st.work_hours, 0) >= 30
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
      coalesce(st.work_days, 0) < 15 OR coalesce(st.work_hours, 0) < 30
    ) AS flag_no_attendance,
    (
      NOT (
        (
          CASE
            WHEN coalesce(st.work_days, 0) >= 15 AND coalesce(st.work_hours, 0) >= 30
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
  JOIN public.users u ON u.id = b.user_id
  LEFT JOIN stats st ON st.staff_id = b.staff_id
  LEFT JOIN sett se ON se.staff_id = b.staff_id
  LEFT JOIN wd w ON w.user_id = b.user_id
  ORDER BY
    coalesce(b.is_active, false) DESC,
    (
      CASE
        WHEN coalesce(st.work_days, 0) >= 15 AND coalesce(st.work_hours, 0) >= 30
          THEN coalesce(st.est_total_usd, 0)
        ELSE coalesce(st.est_commission_usd, 0) + coalesce(st.est_new_bd_usd, 0)
      END
    ) DESC,
    u.short_id NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_bd_month_audit(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bd_month_audit(text) TO service_role;
