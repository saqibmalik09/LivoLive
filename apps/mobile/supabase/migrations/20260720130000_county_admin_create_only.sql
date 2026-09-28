-- County Admin: only create agency for a User ID under their BD.
-- Cannot attach / reassign another person's agency via code or UUID.

DROP FUNCTION IF EXISTS public.county_admin_activate_agency(text, text, text);

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
  v_owner_name text;
  v_bd_user uuid;
  v_agency_code text;
  v_i int;
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

  IF v_ref = '' OR v_ref !~ '^[0-9]+$' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Enter owner User ID only (e.g. 100022). Cannot use agency code or UUID.'
    );
  END IF;

  IF v_bd_ref = '' THEN
    RETURN json_build_object('success', false, 'message', 'Enter BD ID');
  END IF;

  BEGIN
    v_short := v_ref::bigint;
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Invalid User ID');
  END;

  -- Resolve BD: staff_code first, then BD user short_id
  SELECT * INTO v_bd FROM public.business_staff
  WHERE staff_code = v_bd_ref AND is_active = true
    AND public.normalize_staff_role(role) = 'bd'
  LIMIT 1;

  IF v_bd.id IS NULL AND v_bd_ref ~ '^[0-9]+$' THEN
    SELECT u.id INTO v_bd_user
    FROM public.users u
    WHERE u.short_id = v_bd_ref::bigint
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

  IF v_bd.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid BD ID');
  END IF;

  IF v_bd.parent_staff_id IS DISTINCT FROM v_admin.id THEN
    RETURN json_build_object('success', false, 'message', 'BD is not under this County Admin');
  END IF;

  SELECT u.id, u.username INTO v_owner_id, v_owner_name
  FROM public.users u
  WHERE u.short_id = v_short
  LIMIT 1;

  IF v_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'User ID not found');
  END IF;

  -- Existing agency owned by this user only (never someone else's)
  SELECT * INTO v_agency
  FROM public.agencies a
  WHERE a.owner_id = v_owner_id
  ORDER BY a.created_at DESC
  LIMIT 1;

  IF v_agency.id IS NOT NULL THEN
    IF v_agency.sponsor_staff_id IS NOT NULL
       AND v_agency.sponsor_staff_id IS DISTINCT FROM v_bd.id THEN
      RETURN json_build_object(
        'success', false,
        'message', 'This user already has an agency under another BD. Cannot move it.'
      );
    END IF;

    IF v_agency.sponsor_staff_id IS NOT DISTINCT FROM v_bd.id THEN
      RETURN json_build_object(
        'success', true,
        'created', false,
        'agency_id', v_agency.id,
        'agency_code', v_agency.agency_code,
        'bd_staff_id', v_bd.id,
        'message', 'Agency already under this BD'
      );
    END IF;

    -- Unbound agency owned by this user → bind under this BD (not transfer of others)
    UPDATE public.agencies
    SET sponsor_staff_id = v_bd.id,
        approved_by_staff_id = v_admin.id,
        is_active = true
    WHERE id = v_agency.id
      AND owner_id = v_owner_id;

    RETURN json_build_object(
      'success', true,
      'created', false,
      'agency_id', v_agency.id,
      'agency_code', v_agency.agency_code,
      'bd_staff_id', v_bd.id
    );
  END IF;

  -- No agency → create new for this user under BD
  FOR v_i IN 1..20 LOOP
    v_agency_code := lpad((floor(random() * 900000) + 100000)::text, 6, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.agencies WHERE agency_code = v_agency_code
    );
  END LOOP;

  INSERT INTO public.agencies (
    owner_id, name, agency_code, is_active, sponsor_staff_id, approved_by_staff_id
  ) VALUES (
    v_owner_id,
    COALESCE(NULLIF(trim(v_owner_name), ''), 'Agency') || ' Agency',
    v_agency_code,
    true,
    v_bd.id,
    v_admin.id
  )
  RETURNING * INTO v_agency;

  RETURN json_build_object(
    'success', true,
    'created', true,
    'agency_id', v_agency.id,
    'agency_code', v_agency.agency_code,
    'owner_short_id', v_short,
    'bd_staff_id', v_bd.id
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.county_admin_activate_agency(text, text, text) TO authenticated;
