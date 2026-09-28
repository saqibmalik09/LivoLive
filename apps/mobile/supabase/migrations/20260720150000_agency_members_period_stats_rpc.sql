-- Agency owners/admins cannot read members' host_period_stats via RLS (own row only).
-- Period Salary uses get_agency_period_targets (SECURITY DEFINER); Agency Data queried the table directly.

CREATE OR REPLACE FUNCTION public.get_agency_members_period_stats(
  p_agency_id uuid,
  p_period_id text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_period text;
  v_members json;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.agencies a
    WHERE a.id = p_agency_id AND a.owner_id = v_uid
  ) AND NOT EXISTS (
    SELECT 1 FROM public.agency_members am
    WHERE am.agency_id = p_agency_id
      AND am.user_id = v_uid
      AND am.role IN ('owner', 'admin')
  ) THEN
    RETURN json_build_object('success', false, 'message', 'No access');
  END IF;

  v_period := COALESCE(p_period_id, public.get_period_id_for_date(current_date));

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_members
  FROM (
    SELECT
      am.user_id,
      COALESCE(hps.charm_points, 0) AS charm_points,
      COALESCE(hps.total_diamonds, 0) AS total_diamonds,
      COALESCE(hps.valid_days, 0) AS valid_days,
      COALESCE(hps.total_on_mic_seconds, 0) AS total_on_mic_seconds,
      hps.daily_seconds
    FROM public.agency_members am
    LEFT JOIN public.host_period_stats hps
      ON hps.user_id = am.user_id AND hps.period_id = v_period
    WHERE am.agency_id = p_agency_id
      AND (p_user_id IS NULL OR am.user_id = p_user_id)
  ) t;

  RETURN json_build_object(
    'success', true,
    'period_id', v_period,
    'members', v_members
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_agency_members_period_stats(uuid, text, uuid) TO authenticated;
