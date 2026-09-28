-- Host join: accept agency_code OR agency owner's short_id.

CREATE OR REPLACE FUNCTION public.submit_host_agency_application(p_agency_ref text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_ref text := trim(COALESCE(p_agency_ref, ''));
  v_agency public.agencies%ROWTYPE;
  v_owner_id uuid;
  v_short bigint;
  v_app_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF v_ref = '' THEN
    RETURN json_build_object('success', false, 'message', 'Enter agency code or owner ID');
  END IF;

  -- 1) Exact agency_code match
  SELECT * INTO v_agency
  FROM public.agencies
  WHERE agency_code = v_ref
    AND COALESCE(is_active, true) = true
  LIMIT 1;

  -- 2) Owner short_id → their active agency
  IF v_agency.id IS NULL AND v_ref ~ '^[0-9]+$' THEN
    BEGIN
      v_short := v_ref::bigint;
    EXCEPTION WHEN OTHERS THEN
      v_short := NULL;
    END;

    IF v_short IS NOT NULL THEN
      SELECT u.id INTO v_owner_id
      FROM public.users u
      WHERE u.short_id = v_short
      LIMIT 1;

      IF v_owner_id IS NOT NULL THEN
        SELECT * INTO v_agency
        FROM public.agencies a
        WHERE a.owner_id = v_owner_id
          AND COALESCE(a.is_active, true) = true
        ORDER BY a.created_at DESC
        LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF v_agency.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid Agency Code / Owner ID. Check with your Agency Owner.'
    );
  END IF;

  IF v_agency.owner_id = v_uid THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You already own this agency'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.agency_members m
    WHERE m.user_id = v_uid AND m.agency_id = v_agency.id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You are already a host in this agency'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.agency_applications ap
    WHERE ap.user_id = v_uid
      AND ap.agency_id = v_agency.id
      AND ap.status = 'pending'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'You have already applied!');
  END IF;

  INSERT INTO public.agency_applications (user_id, agency_id, status)
  VALUES (v_uid, v_agency.id, 'pending')
  RETURNING id INTO v_app_id;

  RETURN json_build_object(
    'success', true,
    'application_id', v_app_id,
    'agency_id', v_agency.id,
    'agency_code', v_agency.agency_code,
    'agency_name', v_agency.name
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'You have already applied!');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_host_agency_application(text) TO authenticated;

-- Agency owner apply: BD staff_code OR BD user's short_id.
CREATE OR REPLACE FUNCTION public.submit_agency_application(
  p_real_name text,
  p_whatsapp text,
  p_bd_staff_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_code text := trim(COALESCE(p_bd_staff_code, ''));
  v_bd public.business_staff%ROWTYPE;
  v_short bigint;
  v_bd_user uuid;
  v_app_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF v_code = '' THEN
    RETURN json_build_object('success', false, 'message', 'Enter a valid BD ID');
  END IF;

  IF trim(COALESCE(p_real_name, '')) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Real name is required');
  END IF;

  -- 1) staff_code
  SELECT * INTO v_bd
  FROM public.business_staff
  WHERE staff_code = v_code
    AND is_active = true
  LIMIT 1;

  -- 2) BD user's short_id → their active BD staff row
  IF v_bd.id IS NULL AND v_code ~ '^[0-9]+$' THEN
    BEGIN
      v_short := v_code::bigint;
    EXCEPTION WHEN OTHERS THEN
      v_short := NULL;
    END;

    IF v_short IS NOT NULL THEN
      SELECT u.id INTO v_bd_user
      FROM public.users u
      WHERE u.short_id = v_short
      LIMIT 1;

      IF v_bd_user IS NOT NULL THEN
        SELECT * INTO v_bd
        FROM public.business_staff bs
        WHERE bs.user_id = v_bd_user
          AND bs.is_active = true
          AND public.normalize_staff_role(bs.role) = 'bd'
        ORDER BY bs.created_at DESC
        LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF v_bd.id IS NULL OR public.normalize_staff_role(v_bd.role) <> 'bd' THEN
    RETURN json_build_object('success', false, 'message', 'Enter a valid BD ID');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_applications
    WHERE user_id = v_uid AND type = 'agency' AND status = 'pending'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'You have already applied!');
  END IF;

  INSERT INTO public.user_applications (
    user_id, type, real_name, whatsapp_number, target_staff_id, status
  ) VALUES (
    v_uid, 'agency', trim(p_real_name), trim(COALESCE(p_whatsapp, '')), v_bd.id, 'pending'
  )
  RETURNING id INTO v_app_id;

  RETURN json_build_object('success', true, 'application_id', v_app_id);
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'You have already applied!');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_agency_application(text, text, text) TO authenticated;
