-- ROLLBACK: salary period functions as of 2026-10-02 12:25:40.069581+00

CREATE OR REPLACE FUNCTION public.admin_agency_period_audit(p_period_id text)
 RETURNS TABLE(agency_id uuid, agency_name text, agency_code text, owner_user_id uuid, owner_username text, owner_short_id bigint, period_id text, salary_usd numeric, achieved_level integer, total_charm bigint, paid_at timestamp with time zone, settlement_status text, member_count integer, stats_charm bigint, self_gift_charm bigint, self_gift_pct numeric, cash_balance numeric, pending_withdraw_usd numeric, completed_withdraw_usd numeric, implied_cash_usd numeric, salary_ratio numeric, flag_double_pay boolean, flag_over_withdraw boolean, flag_mostly_self_gift boolean, flag_ok boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.admin_bd_month_audit(p_period_yyyy_mm text)
 RETURNS TABLE(staff_id uuid, user_id uuid, username text, short_id bigint, staff_code text, role text, is_active boolean, period_yyyy_mm text, agency_target_usd numeric, work_days integer, work_hours numeric, new_agencies integer, achieved_level integer, est_basic_usd numeric, est_commission_usd numeric, est_new_bd_usd numeric, est_total_usd numeric, payable_usd numeric, basic_qualifies boolean, in_new_bd_window boolean, last_calculated_at timestamp with time zone, settlement_status text, settlement_total_usd numeric, settlement_basic_usd numeric, settlement_commission_usd numeric, settlement_new_bd_usd numeric, paid_at timestamp with time zone, cash_balance numeric, pending_withdraw_usd numeric, completed_withdraw_usd numeric, implied_cash_usd numeric, flag_unpaid_with_due boolean, flag_over_withdraw boolean, flag_no_attendance boolean, flag_ok boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.admin_host_period_audit(p_period_id text)
 RETURNS TABLE(user_id uuid, username text, short_id bigint, agency_id uuid, agency_name text, agency_code text, period_id text, total_diamonds bigint, total_on_mic_seconds bigint, valid_days integer, work_hours numeric, charm_points bigint, self_gift_charm bigint, self_gift_pct numeric, tier_id uuid, tier_name text, est_usd numeric, est_diamonds bigint, diamond_only_usd numeric, payout_id uuid, payout_status text, payout_diamonds bigint, paid_at timestamp with time zone, diamonds_balance bigint, cash_balance numeric, pending_withdraw_usd numeric, flag_unpaid_with_due boolean, flag_withheld boolean, flag_paid_mismatch boolean, flag_mostly_self_gift boolean, flag_blocked_by_attendance boolean, flag_ok boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.execute_agency_period_payout(p_period_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
DECLARE
  r record;
  v_calc record;
  v_paid integer := 0;
  v_owner uuid;
  v_credited numeric;
BEGIN
  IF p_period_id IS NULL
     OR p_period_id !~ '^\d{4}-\d{2}-(A|B)$' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid period; expected YYYY-MM-A or YYYY-MM-B'
    );
  END IF;

  -- Shared by bulk, manual single-agency, and cron payouts.
  PERFORM pg_advisory_xact_lock(
    87201401,
    hashtext(p_period_id)
  );

  FOR r IN
    SELECT id, owner_id
    FROM public.agencies
    WHERE is_active = true
      AND owner_id IS NOT NULL
    ORDER BY id
  LOOP
    IF EXISTS (
      SELECT 1
      FROM public.agency_period_settlements
      WHERE agency_id = r.id
        AND period_id = p_period_id
        AND status = 'paid'
    ) THEN
      CONTINUE;
    END IF;

    SELECT *
    INTO v_calc
    FROM public.calculate_agency_period_salary_per_host(r.id, p_period_id);

    IF COALESCE(v_calc.total_usd, 0) <= 0 THEN
      CONTINUE;
    END IF;

    v_owner := NULL;
    v_credited := NULL;

    -- This row is the idempotency claim. Cash is credited only if this
    -- statement inserted/transitioned the settlement to paid.
    INSERT INTO public.agency_period_settlements (
      agency_id,
      period_id,
      total_charm,
      achieved_level,
      charm_salary_usd,
      agent_salary_usd,
      total_usd,
      owner_user_id,
      status,
      paid_at
    ) VALUES (
      r.id,
      p_period_id,
      v_calc.total_charm,
      v_calc.achieved_level,
      v_calc.charm_salary_usd,
      v_calc.agent_salary_usd,
      v_calc.total_usd,
      r.owner_id,
      'paid',
      now()
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
    RETURNING owner_user_id, total_usd
    INTO v_owner, v_credited;

    IF v_owner IS NULL THEN
      CONTINUE;
    END IF;

    UPDATE public.users
    SET cash_balance = COALESCE(cash_balance, 0) + v_credited
    WHERE id = v_owner;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Agency owner % no longer exists', v_owner;
    END IF;

    INSERT INTO public.transactions (
      user_id,
      amount,
      currency_type,
      transaction_type,
      reference_id,
      description
    ) VALUES (
      v_owner,
      GREATEST(1, ROUND(v_credited)::bigint),
      'cash',
      'salary_payout',
      r.id,
      format(
        'Agency per-host period salary $%s for %s',
        v_credited,
        p_period_id
      )
    );

    v_paid := v_paid + 1;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'period_id', p_period_id,
    'calculation', 'per_host_level_sum',
    'agencies_paid', v_paid
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.execute_bd_monthly_payout(p_period_yyyy_mm text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
$function$
;

CREATE OR REPLACE FUNCTION public.execute_one_agency_period_payout(p_period_id text, p_agency_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
DECLARE
  r record;
  v_calc record;
  v_owner uuid;
  v_credited numeric;
BEGIN
  IF p_period_id IS NULL
     OR p_period_id !~ '^\d{4}-\d{2}-(A|B)$' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid period; expected YYYY-MM-A or YYYY-MM-B'
    );
  END IF;

  IF p_agency_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'agency_id required'
    );
  END IF;

  -- Same lock as the bulk/cron function prevents cross-path races.
  PERFORM pg_advisory_xact_lock(
    87201401,
    hashtext(p_period_id)
  );

  SELECT id, owner_id
  INTO r
  FROM public.agencies
  WHERE id = p_agency_id
    AND is_active = true
    AND owner_id IS NOT NULL;

  IF r.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Agency not found or inactive'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.agency_period_settlements
    WHERE agency_id = r.id
      AND period_id = p_period_id
      AND status = 'paid'
  ) THEN
    RETURN json_build_object(
      'success', true,
      'already_paid', true,
      'period_id', p_period_id,
      'agency_id', p_agency_id
    );
  END IF;

  SELECT *
  INTO v_calc
  FROM public.calculate_agency_period_salary_per_host(r.id, p_period_id);

  IF COALESCE(v_calc.total_usd, 0) <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'No payable agency salary for this period'
    );
  END IF;

  INSERT INTO public.agency_period_settlements (
    agency_id,
    period_id,
    total_charm,
    achieved_level,
    charm_salary_usd,
    agent_salary_usd,
    total_usd,
    owner_user_id,
    status,
    paid_at
  ) VALUES (
    r.id,
    p_period_id,
    v_calc.total_charm,
    v_calc.achieved_level,
    v_calc.charm_salary_usd,
    v_calc.agent_salary_usd,
    v_calc.total_usd,
    r.owner_id,
    'paid',
    now()
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
  RETURNING owner_user_id, total_usd
  INTO v_owner, v_credited;

  IF v_owner IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'already_paid', true,
      'period_id', p_period_id,
      'agency_id', p_agency_id
    );
  END IF;

  UPDATE public.users
  SET cash_balance = COALESCE(cash_balance, 0) + v_credited
  WHERE id = v_owner;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Agency owner % no longer exists', v_owner;
  END IF;

  INSERT INTO public.transactions (
    user_id,
    amount,
    currency_type,
    transaction_type,
    reference_id,
    description
  ) VALUES (
    v_owner,
    GREATEST(1, ROUND(v_credited)::bigint),
    'cash',
    'salary_payout',
    r.id,
    format(
      'Agency per-host period salary $%s for %s',
      v_credited,
      p_period_id
    )
  );

  RETURN json_build_object(
    'success', true,
    'period_id', p_period_id,
    'agency_id', p_agency_id,
    'calculation', 'per_host_level_sum',
    'total_usd', v_credited,
    'owner_user_id', v_owner
  );
END;
$function$
;

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
$function$
;

CREATE OR REPLACE FUNCTION public.get_period_bounds(p_period_id text)
 RETURNS TABLE(start_date date, end_date date, payout_date date)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_year int;
  v_month int;
  v_suffix text;
BEGIN
  v_year := split_part(p_period_id, '-', 1)::int;
  v_month := split_part(p_period_id, '-', 2)::int;
  v_suffix := split_part(p_period_id, '-', 3);

  IF v_suffix IN ('A', 'H1') THEN
    start_date := make_date(v_year, v_month, 1);
    end_date := make_date(v_year, v_month, 15);
    payout_date := make_date(v_year, v_month, 16);
  ELSE
    start_date := make_date(v_year, v_month, 16);
    end_date := (date_trunc('month', make_date(v_year, v_month, 1)) + interval '1 month - 1 day')::date;
    payout_date := (date_trunc('month', make_date(v_year, v_month, 1)) + interval '1 month')::date;
  END IF;
  RETURN NEXT;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_period_id_for_ts(p_ts timestamp with time zone DEFAULT now())
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_local timestamp;
  v_day int;
BEGIN
  v_local := public.policy_local_now(p_ts);
  v_day := EXTRACT(DAY FROM v_local)::int;
  IF v_day <= 15 THEN
    RETURN to_char(v_local, 'YYYY-MM') || '-A';
  END IF;
  RETURN to_char(v_local, 'YYYY-MM') || '-B';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_previous_period_id(p_period_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_year int;
  v_month int;
  v_suffix text;
  v_prev date;
BEGIN
  v_year := split_part(p_period_id, '-', 1)::int;
  v_month := split_part(p_period_id, '-', 2)::int;
  v_suffix := split_part(p_period_id, '-', 3);

  IF v_suffix IN ('B', 'H2') THEN
    RETURN to_char(make_date(v_year, v_month, 1), 'YYYY-MM') || '-A';
  END IF;

  v_prev := (make_date(v_year, v_month, 1) - interval '1 day')::date;
  RETURN to_char(v_prev, 'YYYY-MM') || '-B';
END;
$function$
;

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
$function$
;

CREATE OR REPLACE FUNCTION public.run_scheduled_agency_period_payouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
    PERFORM public.ensure_salary_period(v_period);
    v_res := public.execute_agency_period_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_16_period_a', 'result', v_res);
  END IF;

  IF v_day = 1 THEN
    v_prev := (date_trunc('month', v_local::date) - interval '1 day')::date;
    v_period := to_char(v_prev, 'YYYY-MM') || '-B';
    PERFORM public.ensure_salary_period(v_period);
    v_res := public.execute_agency_period_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_1_prev_period_b', 'result', v_res);
  END IF;

  RETURN json_build_object('ran', false, 'reason', 'not_payout_day', 'local_day', v_day);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.run_scheduled_bd_period_payouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
$function$
;


-- data rollback for the in-flight period
UPDATE public.salary_periods SET period_id='2026-10-A', start_date='2026-10-01', end_date='2026-10-15', payout_date='2026-10-16' WHERE period_id='2026-10-M';
UPDATE public.host_period_stats SET period_id='2026-10-A' WHERE period_id='2026-10-M';
