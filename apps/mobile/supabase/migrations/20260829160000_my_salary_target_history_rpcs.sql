-- Own-row history for mobile role centers (host / agency / BD).
-- Settlements tables are RLS-locked; these SECURITY DEFINER RPCs return only
-- the caller's data so past period progress + paid amounts survive rollover.

-- ---------------------------------------------------------------------------
-- Host: past period stats + paid host payout for that period
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_host_period_history(
  p_limit integer DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_limit integer := GREATEST(1, LEAST(COALESCE(p_limit, 24), 48));
  v_rows jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.period_id DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      hps.period_id,
      COALESCE(hps.charm_points, 0)::bigint AS charm_points,
      COALESCE(hps.total_diamonds, 0)::bigint AS total_diamonds,
      COALESCE(hps.total_on_mic_seconds, 0)::bigint AS total_on_mic_seconds,
      COALESCE(hps.valid_days, 0)::integer AS valid_days,
      pay.total_amount AS paid_amount,
      pay.paid_at,
      pay.status AS payout_status
    FROM public.host_period_stats hps
    LEFT JOIN LATERAL (
      SELECT p.total_amount, p.paid_at, p.status
      FROM public.host_salary_payouts p
      WHERE p.beneficiary_user_id = hps.user_id
        AND p.period_id = hps.period_id
        AND p.beneficiary_role = 'host'
        AND p.status = 'paid'
      ORDER BY p.paid_at DESC NULLS LAST
      LIMIT 1
    ) pay ON true
    WHERE hps.user_id = v_uid
    ORDER BY hps.period_id DESC
    LIMIT v_limit
  ) t;

  RETURN jsonb_build_object('success', true, 'rows', v_rows);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_host_period_history(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_host_period_history(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_host_period_history(integer) TO service_role;

-- ---------------------------------------------------------------------------
-- Agency owner: settlement history for their agency
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_agency_settlement_history(
  p_agency_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_limit integer := GREATEST(1, LEAST(COALESCE(p_limit, 24), 48));
  v_agency_id uuid;
  v_rows jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_agency_id IS NOT NULL THEN
    SELECT a.id INTO v_agency_id
    FROM public.agencies a
    WHERE a.id = p_agency_id
      AND a.owner_id = v_uid
    LIMIT 1;
  ELSE
    SELECT a.id INTO v_agency_id
    FROM public.agencies a
    WHERE a.owner_id = v_uid
      AND COALESCE(a.is_active, true)
    ORDER BY a.id DESC
    LIMIT 1;
  END IF;

  IF v_agency_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_agency_owner');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.period_id DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      s.period_id,
      s.agency_id,
      COALESCE(s.total_charm, 0)::bigint AS total_charm,
      COALESCE(s.achieved_level, 0)::integer AS achieved_level,
      COALESCE(s.charm_salary_usd, 0)::numeric AS charm_salary_usd,
      COALESCE(s.agent_salary_usd, 0)::numeric AS agent_salary_usd,
      COALESCE(s.total_usd, 0)::numeric AS total_usd,
      s.status,
      s.paid_at,
      s.created_at
    FROM public.agency_period_settlements s
    WHERE s.agency_id = v_agency_id
    ORDER BY s.period_id DESC
    LIMIT v_limit
  ) t;

  RETURN jsonb_build_object(
    'success', true,
    'agency_id', v_agency_id,
    'rows', v_rows
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_agency_settlement_history(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_agency_settlement_history(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_agency_settlement_history(uuid, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- BD staff: settlements + monthly stats (target / level) for same month
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_bd_settlement_history(
  p_limit integer DEFAULT 12
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_limit integer := GREATEST(1, LEAST(COALESCE(p_limit, 12), 36));
  v_staff_id uuid;
  v_rows jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT bs.id INTO v_staff_id
  FROM public.business_staff bs
  WHERE bs.user_id = v_uid
    AND COALESCE(bs.is_active, true)
    AND bs.role IN ('bd', 'bd_admin', 'super_bd', 'county_admin')
  ORDER BY
    CASE bs.role
      WHEN 'super_bd' THEN 1
      WHEN 'county_admin' THEN 2
      WHEN 'bd_admin' THEN 3
      ELSE 4
    END,
    bs.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_staff_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_bd_staff');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.period_yyyy_mm DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT * FROM (
      SELECT
        m.period_yyyy_mm,
        COALESCE(m.agency_target_usd, 0)::numeric AS agency_target_usd,
        COALESCE(s.achieved_level, m.achieved_level, 0)::integer AS achieved_level,
        COALESCE(s.basic_usd, m.est_basic_usd, 0)::numeric AS basic_usd,
        COALESCE(s.commission_usd, m.est_commission_usd, 0)::numeric AS commission_usd,
        COALESCE(s.new_bd_usd, m.est_new_bd_usd, 0)::numeric AS new_bd_usd,
        COALESCE(s.total_usd, m.est_total_usd, 0)::numeric AS total_usd,
        s.status AS settlement_status,
        s.paid_at,
        (s.id IS NOT NULL) AS has_settlement
      FROM public.bd_staff_monthly_stats m
      LEFT JOIN public.bd_staff_settlements s
        ON s.staff_id = m.staff_id
       AND s.period_yyyy_mm = m.period_yyyy_mm
      WHERE m.staff_id = v_staff_id

      UNION ALL

      SELECT
        s.period_yyyy_mm,
        0::numeric AS agency_target_usd,
        COALESCE(s.achieved_level, 0)::integer AS achieved_level,
        COALESCE(s.basic_usd, 0)::numeric AS basic_usd,
        COALESCE(s.commission_usd, 0)::numeric AS commission_usd,
        COALESCE(s.new_bd_usd, 0)::numeric AS new_bd_usd,
        COALESCE(s.total_usd, 0)::numeric AS total_usd,
        s.status AS settlement_status,
        s.paid_at,
        true AS has_settlement
      FROM public.bd_staff_settlements s
      WHERE s.staff_id = v_staff_id
        AND NOT EXISTS (
          SELECT 1 FROM public.bd_staff_monthly_stats m
          WHERE m.staff_id = s.staff_id AND m.period_yyyy_mm = s.period_yyyy_mm
        )
    ) u
    ORDER BY u.period_yyyy_mm DESC
    LIMIT v_limit
  ) t;

  RETURN jsonb_build_object(
    'success', true,
    'staff_id', v_staff_id,
    'rows', v_rows
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_bd_settlement_history(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_bd_settlement_history(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_bd_settlement_history(integer) TO service_role;
