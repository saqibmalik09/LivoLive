-- One-glance audit: agency salary vs cash vs withdrawals vs self-gift farm %.
CREATE OR REPLACE FUNCTION public.admin_agency_period_audit(p_period_id text)
RETURNS TABLE (
  agency_id uuid,
  agency_name text,
  agency_code text,
  owner_user_id uuid,
  owner_username text,
  owner_short_id bigint,
  period_id text,
  salary_usd numeric,
  achieved_level int,
  total_charm bigint,
  paid_at timestamptz,
  settlement_status text,
  member_count int,
  stats_charm bigint,
  self_gift_charm bigint,
  self_gift_pct numeric,
  cash_balance numeric,
  pending_withdraw_usd numeric,
  completed_withdraw_usd numeric,
  implied_cash_usd numeric,
  salary_ratio numeric,
  flag_double_pay boolean,
  flag_over_withdraw boolean,
  flag_mostly_self_gift boolean,
  flag_ok boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_start timestamptz;
  v_end timestamptz;
  v_y int;
  v_m int;
  v_half text;
BEGIN
  IF p_period_id IS NULL OR p_period_id !~ '^\d{4}-\d{2}-[ABab]$' THEN
    RAISE EXCEPTION 'Invalid period_id';
  END IF;

  v_y := substring(p_period_id from 1 for 4)::int;
  v_m := substring(p_period_id from 6 for 2)::int;
  v_half := upper(substring(p_period_id from 9 for 1));

  IF v_half = 'A' THEN
    v_start := make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC');
    v_end := make_timestamptz(v_y, v_m, 16, 0, 0, 0, 'UTC');
  ELSE
    v_start := make_timestamptz(v_y, v_m, 16, 0, 0, 0, 'UTC');
    v_end := (make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC') + interval '1 month');
  END IF;

  RETURN QUERY
  WITH settled AS (
    SELECT
      s.agency_id,
      s.period_id,
      s.total_usd,
      s.achieved_level,
      s.total_charm,
      s.paid_at,
      s.status,
      s.owner_user_id
    FROM public.agency_period_settlements s
    WHERE s.period_id = p_period_id
  ),
  members AS (
    SELECT am.agency_id, count(*)::int AS member_count
    FROM public.agency_members am
    WHERE am.agency_id IN (SELECT settled.agency_id FROM settled)
    GROUP BY am.agency_id
  ),
  stats AS (
    SELECT am.agency_id, coalesce(sum(hps.charm_points), 0)::bigint AS stats_charm
    FROM public.agency_members am
    LEFT JOIN public.host_period_stats hps
      ON hps.user_id = am.user_id AND hps.period_id = p_period_id
    WHERE am.agency_id IN (SELECT settled.agency_id FROM settled)
    GROUP BY am.agency_id
  ),
  self_gifts AS (
    SELECT
      am.agency_id,
      coalesce(sum(gl.charm_amount), 0)::bigint AS self_gift_charm
    FROM public.agency_members am
    JOIN public.gift_logs gl
      ON gl.receiver_id = am.user_id
     AND gl.sender_id = gl.receiver_id
     AND gl.created_at >= v_start
     AND gl.created_at < v_end
    WHERE am.agency_id IN (SELECT settled.agency_id FROM settled)
    GROUP BY am.agency_id
  ),
  wd AS (
    SELECT
      w.user_id,
      coalesce(sum(w.amount) FILTER (WHERE w.status = 'pending'), 0)::numeric AS pending_usd,
      coalesce(sum(w.amount) FILTER (
        WHERE w.status IN ('approved', 'completed', 'paid')
      ), 0)::numeric AS completed_usd
    FROM public.wallet_withdrawals w
    WHERE w.user_id IN (SELECT settled.owner_user_id FROM settled)
    GROUP BY w.user_id
  )
  SELECT
    a.id AS agency_id,
    coalesce(a.name, 'Agency')::text AS agency_name,
    a.agency_code::text,
    u.id AS owner_user_id,
    coalesce(u.username, 'User')::text AS owner_username,
    u.short_id::bigint AS owner_short_id,
    st.period_id::text,
    st.total_usd::numeric AS salary_usd,
    coalesce(st.achieved_level, 0)::int,
    coalesce(st.total_charm, 0)::bigint,
    st.paid_at,
    st.status::text AS settlement_status,
    coalesce(m.member_count, 0)::int,
    coalesce(ss.stats_charm, 0)::bigint,
    coalesce(sg.self_gift_charm, 0)::bigint,
    CASE
      WHEN coalesce(ss.stats_charm, 0) > 0
        THEN round((coalesce(sg.self_gift_charm, 0)::numeric * 100) / ss.stats_charm, 1)
      ELSE 0::numeric
    END AS self_gift_pct,
    coalesce(u.cash_balance, 0)::numeric AS cash_balance,
    coalesce(w.pending_usd, 0)::numeric AS pending_withdraw_usd,
    coalesce(w.completed_usd, 0)::numeric AS completed_withdraw_usd,
    (coalesce(u.cash_balance, 0) + coalesce(w.pending_usd, 0))::numeric AS implied_cash_usd,
    CASE
      WHEN coalesce(st.total_usd, 0) > 0
        THEN round(
          (coalesce(u.cash_balance, 0) + coalesce(w.pending_usd, 0)) / st.total_usd,
          2
        )
      ELSE NULL
    END AS salary_ratio,
    (
      coalesce(st.total_usd, 0) > 0
      AND (coalesce(u.cash_balance, 0) + coalesce(w.pending_usd, 0))
          > st.total_usd * 1.01
    ) AS flag_double_pay,
    (
      coalesce(w.pending_usd, 0) > coalesce(st.total_usd, 0) + 0.01
    ) AS flag_over_withdraw,
    (
      CASE
        WHEN coalesce(ss.stats_charm, 0) > 0
          THEN (coalesce(sg.self_gift_charm, 0)::numeric * 100) / ss.stats_charm
        ELSE 0
      END
    ) >= 50 AS flag_mostly_self_gift,
    (
      NOT (
        coalesce(st.total_usd, 0) > 0
        AND (coalesce(u.cash_balance, 0) + coalesce(w.pending_usd, 0))
            > st.total_usd * 1.01
      )
      AND NOT (coalesce(w.pending_usd, 0) > coalesce(st.total_usd, 0) + 0.01)
    ) AS flag_ok
  FROM settled st
  JOIN public.agencies a ON a.id = st.agency_id
  JOIN public.users u ON u.id = st.owner_user_id
  LEFT JOIN members m ON m.agency_id = st.agency_id
  LEFT JOIN stats ss ON ss.agency_id = st.agency_id
  LEFT JOIN self_gifts sg ON sg.agency_id = st.agency_id
  LEFT JOIN wd w ON w.user_id = st.owner_user_id
  ORDER BY st.total_usd DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_agency_period_audit(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_agency_period_audit(text) TO service_role;
