-- County Admin "Activate Agency": accept agency UUID, agency_code, or owner short_id.
-- BD field: staff_code or BD user's short_id.

DROP FUNCTION IF EXISTS public.county_admin_activate_agency(uuid, text, text);

CREATE OR REPLACE FUNCTION public.county_admin_activate_agency(
  p_agency_ref text,
  p_bd_staff_code text,
  p_admin_staff_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_admin public.business_staff%ROWTYPE;
  v_bd public.business_staff%ROWTYPE;
  v_agency public.agencies%ROWTYPE;
  v_ref text := trim(COALESCE(p_agency_ref, ''));
  v_bd_ref text := trim(COALESCE(p_bd_staff_code, ''));
  v_short bigint;
  v_owner_id uuid;
  v_bd_user uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_admin FROM public.business_staff
  WHERE staff_code = trim(p_admin_staff_code) AND is_active = true
    AND public.normalize_staff_role(role) = 'county_admin';

  IF v_admin.id IS NULL OR v_admin.user_id IS DISTINCT FROM v_uid THEN
    RETURN json_build_object('success', false, 'message', 'Invalid County Admin ID');
  END IF;

  IF v_ref = '' THEN
    RETURN json_build_object('success', false, 'message', 'Enter Agency ID (owner ID / code / UUID)');
  END IF;

  IF v_bd_ref = '' THEN
    RETURN json_build_object('success', false, 'message', 'Enter BD ID');
  END IF;

  -- Resolve BD: staff_code first, then BD user short_id
  SELECT * INTO v_bd FROM public.business_staff
  WHERE staff_code = v_bd_ref AND is_active = true
    AND public.normalize_staff_role(role) = 'bd'
  LIMIT 1;

  IF v_bd.id IS NULL AND v_bd_ref ~ '^[0-9]+$' THEN
    BEGIN
      v_short := v_bd_ref::bigint;
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

  IF v_bd.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid BD ID');
  END IF;

  IF v_bd.parent_staff_id IS DISTINCT FROM v_admin.id THEN
    RETURN json_build_object('success', false, 'message', 'BD is not under this County Admin');
  END IF;

  -- Resolve agency: UUID → agency_code → owner short_id
  IF v_ref ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    SELECT * INTO v_agency FROM public.agencies WHERE id = v_ref::uuid LIMIT 1;
  END IF;

  IF v_agency.id IS NULL THEN
    SELECT * INTO v_agency
    FROM public.agencies
    WHERE agency_code = v_ref
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

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
        ORDER BY a.created_at DESC
        LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF v_agency.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Agency not found. Use owner User ID, agency code, or UUID.'
    );
  END IF;

  IF v_agency.sponsor_staff_id IS NOT NULL AND v_agency.sponsor_staff_id IS DISTINCT FROM v_bd.id THEN
    RETURN json_build_object('success', false, 'message', 'Agency already bound to another BD');
  END IF;

  UPDATE public.agencies
  SET sponsor_staff_id = v_bd.id,
      approved_by_staff_id = v_admin.id,
      is_active = true
  WHERE id = v_agency.id;

  RETURN json_build_object(
    'success', true,
    'agency_id', v_agency.id,
    'agency_code', v_agency.agency_code,
    'bd_staff_id', v_bd.id
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.county_admin_activate_agency(text, text, text) TO authenticated;
