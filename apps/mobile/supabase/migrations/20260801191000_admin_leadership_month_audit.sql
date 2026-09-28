-- Super Admin + County Admin monthly audit (gift commission + tree + cash/WD).
-- These roles are not paid via bd_staff_settlements; commission is from earning_logs.

CREATE OR REPLACE FUNCTION public.admin_leadership_month_audit(p_period_yyyy_mm text)
RETURNS TABLE (
  staff_id uuid,
  user_id uuid,
  username text,
  short_id bigint,
  staff_code text,
  role text,
  normalized_role text,
  is_active boolean,
  period_yyyy_mm text,
  parent_staff_id uuid,
  parent_username text,
  child_staff_count int,
  agency_count int,
  host_count int,
  commission_diamonds bigint,
  commission_usd numeric,
  gift_events int,
  diamonds_balance bigint,
  cash_balance numeric,
  pending_withdraw_usd numeric,
  completed_withdraw_usd numeric,
  implied_cash_usd numeric,
  flag_inactive_with_commission boolean,
  flag_over_withdraw boolean,
  flag_no_downline boolean,
  flag_ok boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
#variable_conflict use_column
DECLARE
  v_start timestamptz;
  v_end timestamptz;
  v_rate numeric;
BEGIN
  IF p_period_yyyy_mm IS NULL OR p_period_yyyy_mm !~ '^\d{4}-\d{2}$' THEN
    RAISE EXCEPTION 'Invalid period_yyyy_mm (want YYYY-MM)';
  END IF;

  v_start := (p_period_yyyy_mm || '-01')::date::timestamptz;
  v_end := (date_trunc('month', v_start) + interval '1 month');

  SELECT COALESCE(diamonds_per_dollar, 1000)::numeric
    INTO v_rate
  FROM public.salary_chain_configs
  WHERE id = 1;
  IF v_rate IS NULL OR v_rate <= 0 THEN
    v_rate := 1000;
  END IF;

  RETURN QUERY
  WITH leaders AS (
    SELECT
      bs.id AS staff_id,
      bs.user_id,
      bs.staff_code,
      bs.role,
      public.normalize_staff_role(bs.role) AS nrole,
      bs.is_active,
      bs.parent_staff_id
    FROM public.business_staff bs
    WHERE public.normalize_staff_role(bs.role) IN ('super_bd', 'county_admin')
  ),
  -- All descendant staff ids per leader (recursive).
  tree AS (
    WITH RECURSIVE walk AS (
      SELECT l.staff_id AS root_id, bs.id AS staff_id, 0 AS depth
      FROM leaders l
      JOIN public.business_staff bs ON bs.parent_staff_id = l.staff_id
      UNION ALL
      SELECT w.root_id, bs.id, w.depth + 1
      FROM walk w
      JOIN public.business_staff bs ON bs.parent_staff_id = w.staff_id
      WHERE w.depth < 20
    )
    SELECT root_id, staff_id FROM walk
  ),
  child_counts AS (
    SELECT root_id AS staff_id, count(*)::int AS child_staff_count
    FROM tree
    GROUP BY root_id
  ),
  agency_scope AS (
    -- Agencies sponsored by leader OR any descendant staff.
    SELECT
      l.staff_id,
      a.id AS agency_id
    FROM leaders l
    JOIN public.agencies a ON a.sponsor_staff_id = l.staff_id
    UNION
    SELECT
      t.root_id AS staff_id,
      a.id AS agency_id
    FROM tree t
    JOIN public.agencies a ON a.sponsor_staff_id = t.staff_id
  ),
  agency_counts AS (
    SELECT s.staff_id, count(DISTINCT s.agency_id)::int AS agency_count
    FROM agency_scope s
    GROUP BY s.staff_id
  ),
  host_counts AS (
    SELECT
      s.staff_id,
      count(DISTINCT am.user_id)::int AS host_count
    FROM agency_scope s
    JOIN public.agency_members am ON am.agency_id = s.agency_id
    GROUP BY s.staff_id
  ),
  commissions AS (
    SELECT
      l.staff_id,
      CASE
        WHEN l.nrole = 'super_bd' THEN coalesce(sum(el.super_bd_amount), 0)
        ELSE coalesce(sum(el.bd_admin_amount), 0)
      END::bigint AS commission_diamonds,
      CASE
        WHEN l.nrole = 'super_bd' THEN count(*) FILTER (WHERE el.super_bd_amount > 0)
        ELSE count(*) FILTER (WHERE el.bd_admin_amount > 0)
      END::int AS gift_events
    FROM leaders l
    LEFT JOIN public.earning_logs el
      ON el.created_at >= v_start
     AND el.created_at < v_end
     AND (
       (l.nrole = 'super_bd' AND el.super_bd_staff_id = l.staff_id)
       OR (l.nrole = 'county_admin' AND el.bd_admin_staff_id = l.staff_id)
     )
    GROUP BY l.staff_id, l.nrole
  ),
  wd AS (
    SELECT
      w.user_id,
      coalesce(sum(w.amount) FILTER (WHERE w.status = 'pending'), 0)::numeric AS pending_usd,
      coalesce(sum(w.amount) FILTER (
        WHERE w.status IN ('approved', 'completed', 'paid')
      ), 0)::numeric AS completed_usd
    FROM public.wallet_withdrawals w
    WHERE w.user_id IN (SELECT leaders.user_id FROM leaders)
    GROUP BY w.user_id
  ),
  parents AS (
    SELECT
      l.staff_id,
      pu.username AS parent_username
    FROM leaders l
    LEFT JOIN public.business_staff ps ON ps.id = l.parent_staff_id
    LEFT JOIN public.users pu ON pu.id = ps.user_id
  )
  SELECT
    l.staff_id,
    l.user_id,
    coalesce(u.username, 'User')::text AS username,
    u.short_id::bigint,
    l.staff_code::text,
    l.role::text,
    l.nrole::text AS normalized_role,
    coalesce(l.is_active, false) AS is_active,
    p_period_yyyy_mm::text,
    l.parent_staff_id,
    p.parent_username::text,
    coalesce(cc.child_staff_count, 0)::int,
    coalesce(ac.agency_count, 0)::int,
    coalesce(hc.host_count, 0)::int,
    coalesce(cm.commission_diamonds, 0)::bigint,
    round(coalesce(cm.commission_diamonds, 0)::numeric / v_rate, 2) AS commission_usd,
    coalesce(cm.gift_events, 0)::int,
    coalesce(u.diamonds, 0)::bigint AS diamonds_balance,
    coalesce(u.cash_balance, 0)::numeric AS cash_balance,
    coalesce(w.pending_usd, 0)::numeric AS pending_withdraw_usd,
    coalesce(w.completed_usd, 0)::numeric AS completed_withdraw_usd,
    (coalesce(u.cash_balance, 0) + coalesce(w.pending_usd, 0))::numeric AS implied_cash_usd,
    (
      coalesce(l.is_active, false) = false
      AND coalesce(cm.commission_diamonds, 0) > 0
    ) AS flag_inactive_with_commission,
    (
      -- Cash WD while this month gift-commission is zero (worth a look).
      coalesce(w.pending_usd, 0) > 0
      AND coalesce(cm.commission_diamonds, 0) = 0
    ) AS flag_over_withdraw,
    (
      coalesce(l.is_active, false) = true
      AND coalesce(ac.agency_count, 0) = 0
      AND coalesce(cc.child_staff_count, 0) = 0
    ) AS flag_no_downline,
    (
      NOT (
        coalesce(l.is_active, false) = false
        AND coalesce(cm.commission_diamonds, 0) > 0
      )
      AND NOT (
        coalesce(w.pending_usd, 0) > 0
        AND coalesce(cm.commission_diamonds, 0) = 0
      )
    ) AS flag_ok
  FROM leaders l
  JOIN public.users u ON u.id = l.user_id
  LEFT JOIN commissions cm ON cm.staff_id = l.staff_id
  LEFT JOIN child_counts cc ON cc.staff_id = l.staff_id
  LEFT JOIN agency_counts ac ON ac.staff_id = l.staff_id
  LEFT JOIN host_counts hc ON hc.staff_id = l.staff_id
  LEFT JOIN wd w ON w.user_id = l.user_id
  LEFT JOIN parents p ON p.staff_id = l.staff_id
  ORDER BY
    CASE l.nrole WHEN 'super_bd' THEN 0 ELSE 1 END,
    coalesce(cm.commission_diamonds, 0) DESC,
    coalesce(ac.agency_count, 0) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_leadership_month_audit(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_leadership_month_audit(text) TO service_role;
