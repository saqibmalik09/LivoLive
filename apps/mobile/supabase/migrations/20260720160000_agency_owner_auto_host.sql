-- Agency owner auto-joins own agency as host (agency_members).
-- Fixes: owner missing from Host List, Agency Data, period stats joins.

CREATE OR REPLACE FUNCTION public.ensure_agency_owner_is_member(p_agency_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_owner_id uuid;
BEGIN
  SELECT owner_id INTO v_owner_id
  FROM public.agencies
  WHERE id = p_agency_id;

  IF v_owner_id IS NULL THEN
    RETURN;
  END IF;

  -- One agency per user (agency_members.user_id UNIQUE)
  DELETE FROM public.agency_members
  WHERE user_id = v_owner_id
    AND agency_id IS DISTINCT FROM p_agency_id;

  INSERT INTO public.agency_members (agency_id, user_id, role)
  VALUES (p_agency_id, v_owner_id, 'host')
  ON CONFLICT (user_id) DO UPDATE
    SET agency_id = EXCLUDED.agency_id,
        role = 'host';
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_agencies_owner_as_member()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
BEGIN
  PERFORM public.ensure_agency_owner_is_member(NEW.id);
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS agencies_owner_as_member ON public.agencies;
CREATE TRIGGER agencies_owner_as_member
  AFTER INSERT ON public.agencies
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_agencies_owner_as_member();

-- Application approve → new agency
CREATE OR REPLACE FUNCTION public.approve_agency_application(
    p_application_id uuid,
    p_approver_user_id uuid DEFAULT NULL,
    p_is_official boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_app public.user_applications%ROWTYPE;
    v_staff public.business_staff%ROWTYPE;
    v_agency_code text;
    v_agency_id uuid;
BEGIN
    SELECT * INTO v_app
    FROM public.user_applications
    WHERE id = p_application_id
    FOR UPDATE;

    IF v_app.id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Application not found');
    END IF;

    IF v_app.type <> 'agency' THEN
        RETURN json_build_object('success', false, 'message', 'Not an agency application');
    END IF;

    IF v_app.status <> 'pending' THEN
        RETURN json_build_object('success', false, 'message', 'Application already processed');
    END IF;

    IF EXISTS (SELECT 1 FROM public.agencies WHERE owner_id = v_app.user_id) THEN
        RETURN json_build_object('success', false, 'message', 'User already owns an agency');
    END IF;

    IF NOT p_is_official THEN
        IF p_approver_user_id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Approver required');
        END IF;

        SELECT * INTO v_staff
        FROM public.business_staff
        WHERE user_id = p_approver_user_id AND is_active = true;

        IF v_staff.id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Not authorized staff');
        END IF;

        IF v_app.target_staff_id IS NOT NULL AND v_app.target_staff_id <> v_staff.id THEN
            IF NOT public.is_staff_descendant(v_staff.id, v_app.target_staff_id) THEN
                RETURN json_build_object('success', false, 'message', 'Application not assigned to you');
            END IF;
        END IF;
    END IF;

    v_agency_code := lpad((floor(random() * 900000) + 100000)::text, 6, '0');

    INSERT INTO public.agencies (
        owner_id,
        name,
        agency_code,
        is_active,
        sponsor_staff_id,
        approved_by_staff_id
    )
    VALUES (
        v_app.user_id,
        v_app.real_name || '''s Agency',
        v_agency_code,
        true,
        CASE WHEN p_is_official THEN v_app.target_staff_id ELSE COALESCE(v_app.target_staff_id, v_staff.id) END,
        CASE WHEN p_is_official THEN NULL ELSE v_staff.id END
    )
    RETURNING id INTO v_agency_id;

    PERFORM public.ensure_agency_owner_is_member(v_agency_id);

    UPDATE public.user_applications
    SET status = 'approved', updated_at = now()
    WHERE id = p_application_id;

    RETURN json_build_object(
        'success', true,
        'agency_id', v_agency_id,
        'agency_code', v_agency_code
    );
END;
$function$;

-- Super BD self-create agency
CREATE OR REPLACE FUNCTION public.create_staff_agency(
    p_staff_user_id uuid,
    p_agency_name text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_staff public.business_staff%ROWTYPE;
    v_agency_code text;
    v_agency_id uuid;
BEGIN
    SELECT * INTO v_staff
    FROM public.business_staff
    WHERE user_id = p_staff_user_id AND is_active = true;

    IF v_staff.id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Active staff role required');
    END IF;

    IF EXISTS (SELECT 1 FROM public.agencies WHERE owner_id = p_staff_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'You already own an agency');
    END IF;

    v_agency_code := lpad((floor(random() * 900000) + 100000)::text, 6, '0');

    INSERT INTO public.agencies (
        owner_id, name, agency_code, is_active, sponsor_staff_id, approved_by_staff_id
    )
    VALUES (
        p_staff_user_id,
        COALESCE(NULLIF(trim(p_agency_name), ''), 'My Agency'),
        v_agency_code,
        true,
        v_staff.id,
        v_staff.id
    )
    RETURNING id INTO v_agency_id;

    PERFORM public.ensure_agency_owner_is_member(v_agency_id);

    RETURN json_build_object(
        'success', true,
        'agency_id', v_agency_id,
        'agency_code', v_agency_code
    );
END;
$function$;

-- County Admin / Super BD create for user
CREATE OR REPLACE FUNCTION public.create_agency_for_owner_under_bd(
  p_owner_user_ref text,
  p_bd_ref text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_me public.business_staff%ROWTYPE;
  v_me_role text;
  v_bd public.business_staff%ROWTYPE;
  v_agency public.agencies%ROWTYPE;
  v_ref text := trim(COALESCE(p_owner_user_ref, ''));
  v_bd_ref text := trim(COALESCE(p_bd_ref, ''));
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

  SELECT * INTO v_me
  FROM public.business_staff
  WHERE user_id = v_uid AND is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_me.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Active staff role required');
  END IF;

  v_me_role := public.normalize_staff_role(v_me.role);
  IF v_me_role NOT IN ('county_admin', 'super_bd') THEN
    RETURN json_build_object('success', false, 'message', 'Only County Admin or Super Admin can create agencies');
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

  IF v_me_role = 'county_admin' THEN
    IF v_bd.parent_staff_id IS DISTINCT FROM v_me.id THEN
      RETURN json_build_object('success', false, 'message', 'BD is not under this County Admin');
    END IF;
  ELSIF v_me_role = 'super_bd' THEN
    IF v_bd.parent_staff_id IS DISTINCT FROM v_me.id
       AND NOT public.is_staff_descendant(v_me.id, v_bd.id) THEN
      RETURN json_build_object('success', false, 'message', 'BD is not in your network');
    END IF;
  END IF;

  SELECT u.id, u.username INTO v_owner_id, v_owner_name
  FROM public.users u
  WHERE u.short_id = v_short
  LIMIT 1;

  IF v_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'User ID not found');
  END IF;

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
      PERFORM public.ensure_agency_owner_is_member(v_agency.id);
      RETURN json_build_object(
        'success', true,
        'created', false,
        'agency_id', v_agency.id,
        'agency_code', v_agency.agency_code,
        'bd_staff_id', v_bd.id,
        'message', 'Agency already under this BD'
      );
    END IF;

    UPDATE public.agencies
    SET sponsor_staff_id = v_bd.id,
        approved_by_staff_id = v_me.id,
        is_active = true
    WHERE id = v_agency.id
      AND owner_id = v_owner_id;

    PERFORM public.ensure_agency_owner_is_member(v_agency.id);

    RETURN json_build_object(
      'success', true,
      'created', false,
      'agency_id', v_agency.id,
      'agency_code', v_agency.agency_code,
      'bd_staff_id', v_bd.id
    );
  END IF;

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
    v_me.id
  )
  RETURNING * INTO v_agency;

  PERFORM public.ensure_agency_owner_is_member(v_agency.id);

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

-- Backfill all existing agencies (e.g. SK LIVE Official — Sk_Boys)
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT id FROM public.agencies
    WHERE COALESCE(is_active, true) = true
  LOOP
    PERFORM public.ensure_agency_owner_is_member(r.id);
  END LOOP;
END $$;
