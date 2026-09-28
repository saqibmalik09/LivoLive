-- Align mobile/admin agency target display with per-host payout formula.

CREATE OR REPLACE FUNCTION public.get_agency_period_targets(
  p_agency_id uuid,
  p_period_id text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_period text;
  v_calc record;
  v_hosts json;
  b record;
  v_owner uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT owner_id INTO v_owner
  FROM public.agencies
  WHERE id = p_agency_id;

  IF v_owner IS DISTINCT FROM v_uid
     AND NOT EXISTS (
       SELECT 1
       FROM public.agency_members
       WHERE agency_id = p_agency_id
         AND user_id = v_uid
         AND role IN ('owner', 'admin')
     ) THEN
    RETURN json_build_object('success', false, 'message', 'No access');
  END IF;

  v_period := COALESCE(p_period_id, public.get_period_id_for_date(current_date));
  SELECT * INTO b FROM public.get_period_bounds(v_period);

  SELECT *
  INTO v_calc
  FROM public.calculate_agency_period_salary_per_host(p_agency_id, v_period);

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_hosts
  FROM (
    SELECT
      am.user_id,
      u.username,
      u.short_id,
      u.avatar_url,
      COALESCE(hps.charm_points, 0) AS charm_points,
      COALESCE(m.level, 0) AS achieved_level,
      COALESCE(m.charm_salary_usd, 0) AS estimated_charm_salary_usd,
      COALESCE(m.agent_salary_usd, 0) AS estimated_agent_salary_usd,
      COALESCE(m.charm_salary_usd, 0) + COALESCE(m.agent_salary_usd, 0)
        AS estimated_total_usd
    FROM public.agency_members am
    JOIN public.users u ON u.id = am.user_id
    LEFT JOIN public.host_period_stats hps
      ON hps.user_id = am.user_id
     AND hps.period_id = v_period
    LEFT JOIN LATERAL (
      SELECT *
      FROM public.match_agency_salary_level(COALESCE(hps.charm_points, 0))
    ) m ON true
    WHERE am.agency_id = p_agency_id
    ORDER BY COALESCE(hps.charm_points, 0) DESC
  ) t;

  RETURN json_build_object(
    'success', true,
    'period_id', v_period,
    'start_date', b.start_date,
    'end_date', b.end_date,
    'payout_date', b.payout_date,
    'calculation', 'per_host_level_sum',
    'total_charm', COALESCE(v_calc.total_charm, 0),
    'achieved_level', COALESCE(v_calc.achieved_level, 0),
    'charm_salary_usd', COALESCE(v_calc.charm_salary_usd, 0),
    'agent_salary_usd', COALESCE(v_calc.agent_salary_usd, 0),
    'total_usd', COALESCE(v_calc.total_usd, 0),
    'owner_user_id', v_owner,
    'hosts', COALESCE(v_hosts, '[]'::json)
  );
END;
$function$;

ALTER FUNCTION public.get_agency_period_targets(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_agency_period_targets(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_agency_period_targets(uuid, text)
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
