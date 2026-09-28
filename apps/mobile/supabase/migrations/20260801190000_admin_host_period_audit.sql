-- Jobs (host) period audit: tier estimate vs diamond payout vs self-gift / mic.
CREATE OR REPLACE FUNCTION public.admin_host_period_audit(p_period_id text)
RETURNS TABLE (
  user_id uuid,
  username text,
  short_id bigint,
  agency_id uuid,
  agency_name text,
  agency_code text,
  period_id text,
  total_diamonds bigint,
  total_on_mic_seconds bigint,
  valid_days int,
  work_hours numeric,
  charm_points bigint,
  self_gift_charm bigint,
  self_gift_pct numeric,
  tier_id uuid,
  tier_name text,
  est_usd numeric,
  est_diamonds bigint,
  diamond_only_usd numeric,
  payout_id uuid,
  payout_status text,
  payout_diamonds bigint,
  paid_at timestamptz,
  diamonds_balance bigint,
  cash_balance numeric,
  pending_withdraw_usd numeric,
  flag_unpaid_with_due boolean,
  flag_withheld boolean,
  flag_paid_mismatch boolean,
  flag_mostly_self_gift boolean,
  flag_blocked_by_attendance boolean,
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
  v_rate numeric;
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

  SELECT COALESCE(diamonds_per_dollar, 1000)::numeric
    INTO v_rate
  FROM public.salary_chain_configs
  WHERE id = 1;
  IF v_rate IS NULL OR v_rate <= 0 THEN
    v_rate := 1000;
  END IF;

  RETURN QUERY
  WITH host_ids AS (
    SELECT hps.user_id
    FROM public.host_period_stats hps
    WHERE hps.period_id = p_period_id
      AND (
        COALESCE(hps.total_diamonds, 0) > 0
        OR COALESCE(hps.charm_points, 0) > 0
        OR COALESCE(hps.valid_days, 0) > 0
        OR COALESCE(hps.total_on_mic_seconds, 0) > 0
      )
    UNION
    SELECT hsp.beneficiary_user_id
    FROM public.host_salary_payouts hsp
    WHERE hsp.period_id = p_period_id
      AND hsp.beneficiary_role = 'host'
  ),
  stats AS (
    SELECT
      h.user_id,
      COALESCE(hps.total_diamonds, 0)::bigint AS total_diamonds,
      COALESCE(hps.total_on_mic_seconds, 0)::bigint AS total_on_mic_seconds,
      COALESCE(hps.valid_days, 0)::int AS valid_days,
      COALESCE(hps.charm_points, 0)::bigint AS charm_points
    FROM host_ids h
    LEFT JOIN public.host_period_stats hps
      ON hps.user_id = h.user_id AND hps.period_id = p_period_id
  ),
  tiers AS (
    SELECT
      s.user_id,
      t.id AS tier_id,
      t.tier_name,
      COALESCE(t.reward_amount, 0)::numeric AS est_usd,
      (COALESCE(t.reward_amount, 0) * v_rate)::bigint AS est_diamonds,
      COALESCE(td.reward_amount, 0)::numeric AS diamond_only_usd
    FROM stats s
    LEFT JOIN LATERAL (
      SELECT st.*
      FROM public.salary_tiers st
      WHERE COALESCE(st.is_active, true)
        AND st.diamonds_target <= s.total_diamonds
        AND st.hours_target <= (s.total_on_mic_seconds / 3600.0)
        AND st.days_target <= s.valid_days
      ORDER BY st.diamonds_target DESC, st.hours_target DESC, st.days_target DESC
      LIMIT 1
    ) t ON true
    LEFT JOIN LATERAL (
      SELECT st.*
      FROM public.salary_tiers st
      WHERE COALESCE(st.is_active, true)
        AND st.diamonds_target <= s.total_diamonds
      ORDER BY st.diamonds_target DESC
      LIMIT 1
    ) td ON true
  ),
  payouts AS (
    SELECT DISTINCT ON (hsp.beneficiary_user_id)
      hsp.beneficiary_user_id AS user_id,
      hsp.id AS payout_id,
      hsp.status AS payout_status,
      COALESCE(hsp.total_amount, 0)::bigint AS payout_diamonds,
      hsp.paid_at
    FROM public.host_salary_payouts hsp
    WHERE hsp.period_id = p_period_id
      AND hsp.beneficiary_role = 'host'
    ORDER BY hsp.beneficiary_user_id, hsp.paid_at DESC NULLS LAST, hsp.created_at DESC
  ),
  membership AS (
    SELECT DISTINCT ON (am.user_id)
      am.user_id,
      a.id AS agency_id,
      COALESCE(a.name, 'Agency')::text AS agency_name,
      a.agency_code::text AS agency_code
    FROM public.agency_members am
    JOIN public.agencies a ON a.id = am.agency_id
    WHERE am.user_id IN (SELECT host_ids.user_id FROM host_ids)
    ORDER BY am.user_id, am.joined_at DESC NULLS LAST
  ),
  self_gifts AS (
    SELECT
      gl.receiver_id AS user_id,
      COALESCE(sum(gl.charm_amount), 0)::bigint AS self_gift_charm
    FROM public.gift_logs gl
    WHERE gl.sender_id = gl.receiver_id
      AND gl.created_at >= v_start
      AND gl.created_at < v_end
      AND gl.receiver_id IN (SELECT host_ids.user_id FROM host_ids)
    GROUP BY gl.receiver_id
  ),
  wd AS (
    SELECT
      w.user_id,
      COALESCE(sum(w.amount) FILTER (WHERE w.status = 'pending'), 0)::numeric AS pending_usd
    FROM public.wallet_withdrawals w
    WHERE w.user_id IN (SELECT host_ids.user_id FROM host_ids)
    GROUP BY w.user_id
  )
  SELECT
    u.id AS user_id,
    COALESCE(u.username, 'User')::text AS username,
    u.short_id::bigint AS short_id,
    m.agency_id,
    m.agency_name,
    m.agency_code,
    p_period_id::text AS period_id,
    s.total_diamonds,
    s.total_on_mic_seconds,
    s.valid_days,
    round((s.total_on_mic_seconds::numeric / 3600.0), 1) AS work_hours,
    s.charm_points,
    COALESCE(sg.self_gift_charm, 0)::bigint AS self_gift_charm,
    CASE
      WHEN s.charm_points > 0
        THEN round((COALESCE(sg.self_gift_charm, 0)::numeric * 100) / s.charm_points, 1)
      ELSE 0::numeric
    END AS self_gift_pct,
    tr.tier_id,
    tr.tier_name::text,
    COALESCE(tr.est_usd, 0)::numeric AS est_usd,
    COALESCE(tr.est_diamonds, 0)::bigint AS est_diamonds,
    COALESCE(tr.diamond_only_usd, 0)::numeric AS diamond_only_usd,
    po.payout_id,
    po.payout_status::text,
    COALESCE(po.payout_diamonds, 0)::bigint AS payout_diamonds,
    po.paid_at,
    COALESCE(u.diamonds, 0)::bigint AS diamonds_balance,
    COALESCE(u.cash_balance, 0)::numeric AS cash_balance,
    COALESCE(w.pending_usd, 0)::numeric AS pending_withdraw_usd,
    (
      COALESCE(tr.est_diamonds, 0) > 0
      AND COALESCE(po.payout_status, '') IS DISTINCT FROM 'paid'
    ) AS flag_unpaid_with_due,
    (COALESCE(po.payout_status, '') = 'withheld') AS flag_withheld,
    (
      COALESCE(po.payout_status, '') = 'paid'
      AND COALESCE(tr.est_diamonds, 0) > 0
      AND ABS(COALESCE(po.payout_diamonds, 0) - COALESCE(tr.est_diamonds, 0))
          > GREATEST(COALESCE(tr.est_diamonds, 0) * 0.05, 1000)
    ) AS flag_paid_mismatch,
    (
      CASE
        WHEN s.charm_points > 0
          THEN (COALESCE(sg.self_gift_charm, 0)::numeric * 100) / s.charm_points
        ELSE 0
      END
    ) >= 50 AS flag_mostly_self_gift,
    (
      COALESCE(tr.est_usd, 0) = 0
      AND COALESCE(tr.diamond_only_usd, 0) > 0
    ) AS flag_blocked_by_attendance,
    (
      NOT (
        COALESCE(tr.est_diamonds, 0) > 0
        AND COALESCE(po.payout_status, '') IS DISTINCT FROM 'paid'
      )
      AND COALESCE(po.payout_status, '') IS DISTINCT FROM 'withheld'
      AND NOT (
        COALESCE(po.payout_status, '') = 'paid'
        AND COALESCE(tr.est_diamonds, 0) > 0
        AND ABS(COALESCE(po.payout_diamonds, 0) - COALESCE(tr.est_diamonds, 0))
            > GREATEST(COALESCE(tr.est_diamonds, 0) * 0.05, 1000)
      )
    ) AS flag_ok
  FROM stats s
  JOIN public.users u ON u.id = s.user_id
  LEFT JOIN tiers tr ON tr.user_id = s.user_id
  LEFT JOIN payouts po ON po.user_id = s.user_id
  LEFT JOIN membership m ON m.user_id = s.user_id
  LEFT JOIN self_gifts sg ON sg.user_id = s.user_id
  LEFT JOIN wd w ON w.user_id = s.user_id
  ORDER BY
    COALESCE(tr.est_usd, 0) DESC,
    COALESCE(tr.diamond_only_usd, 0) DESC,
    s.total_diamonds DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_host_period_audit(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_host_period_audit(text) TO service_role;
