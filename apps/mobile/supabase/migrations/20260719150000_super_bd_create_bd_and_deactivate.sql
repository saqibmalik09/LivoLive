-- Super BD powers: create BD, deactivate BD/agency in subtree

-- =============================================================================
-- 1. Allow Super BD to create BD (keep County Admin → BD; Super BD caps for CA/AS/CS)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_business_staff(
  p_target_user_id uuid,
  p_role text,
  p_parent_staff_id uuid DEFAULT NULL,
  p_created_by_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_parent public.business_staff%ROWTYPE;
  v_role text := public.normalize_staff_role(p_role);
  v_parent_role text;
  v_new_id uuid;
  v_code text;
  v_count int;
BEGIN
  IF v_role NOT IN ('super_bd', 'county_admin', 'bd', 'assistant', 'customer_service') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid role');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.business_staff
    WHERE user_id = p_target_user_id AND is_active = true
  ) THEN
    RETURN json_build_object('success', false, 'message', 'User already has an active staff role');
  END IF;

  IF v_role = 'super_bd' THEN
    IF p_parent_staff_id IS NOT NULL THEN
      RETURN json_build_object('success', false, 'message', 'Super Admin cannot have a parent staff');
    END IF;
  ELSE
    IF p_parent_staff_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Parent staff is required');
    END IF;

    SELECT * INTO v_parent
    FROM public.business_staff
    WHERE id = p_parent_staff_id AND is_active = true;

    IF v_parent.id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Parent staff not found');
    END IF;

    v_parent_role := public.normalize_staff_role(v_parent.role);

    IF v_parent_role = 'super_bd' THEN
      IF v_role NOT IN ('county_admin', 'bd', 'assistant', 'customer_service') THEN
        RETURN json_build_object(
          'success', false,
          'message', 'Super Admin can only create County Admin, BD, Assistant, or Customer Service'
        );
      END IF;
      SELECT COUNT(*) INTO v_count FROM public.business_staff
      WHERE parent_staff_id = v_parent.id
        AND is_active = true
        AND public.normalize_staff_role(role) = v_role;
      IF v_role = 'county_admin' AND v_count >= 2 THEN
        RETURN json_build_object('success', false, 'message', 'Max 2 County Admins per Super Admin');
      END IF;
      IF v_role = 'assistant' AND v_count >= 2 THEN
        RETURN json_build_object('success', false, 'message', 'Max 2 Assistants per Super Admin');
      END IF;
      IF v_role = 'customer_service' AND v_count >= 4 THEN
        RETURN json_build_object('success', false, 'message', 'Max 4 Customer Service per Super Admin');
      END IF;
      -- BD under Super BD: no hard cap (same as County Admin → BD)
    ELSIF v_parent_role = 'county_admin' THEN
      IF v_role <> 'bd' THEN
        RETURN json_build_object('success', false, 'message', 'County Admin can only create BD');
      END IF;
    ELSE
      RETURN json_build_object('success', false, 'message', 'This role cannot create staff');
    END IF;
  END IF;

  v_code := public.generate_staff_code();

  INSERT INTO public.business_staff (user_id, role, parent_staff_id, staff_code, created_by_user_id)
  VALUES (p_target_user_id, v_role, p_parent_staff_id, v_code, p_created_by_user_id)
  RETURNING id INTO v_new_id;

  IF v_role IN ('assistant', 'customer_service') THEN
    PERFORM public.grant_staff_role_cosmetics(p_target_user_id, v_role);
  END IF;

  RETURN json_build_object(
    'success', true,
    'staff_id', v_new_id,
    'staff_code', v_code,
    'role', v_role
  );
END;
$function$;

-- =============================================================================
-- 2. Super BD deactivate staff (bd / county_admin) in subtree
-- =============================================================================

CREATE OR REPLACE FUNCTION public.super_bd_deactivate_staff(p_staff_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_me public.business_staff%ROWTYPE;
  v_target public.business_staff%ROWTYPE;
  v_role text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_me
  FROM public.business_staff
  WHERE user_id = v_uid AND is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_me.id IS NULL OR public.normalize_staff_role(v_me.role) <> 'super_bd' THEN
    RETURN json_build_object('success', false, 'message', 'Only Super Admin can remove staff');
  END IF;

  SELECT * INTO v_target
  FROM public.business_staff
  WHERE id = p_staff_id AND is_active = true;

  IF v_target.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Staff not found or already inactive');
  END IF;

  v_role := public.normalize_staff_role(v_target.role);
  IF v_role NOT IN ('bd', 'county_admin') THEN
    RETURN json_build_object('success', false, 'message', 'Can only remove BD or County Admin');
  END IF;

  IF v_target.id = v_me.id THEN
    RETURN json_build_object('success', false, 'message', 'Cannot remove yourself');
  END IF;

  IF NOT public.is_staff_descendant(v_me.id, v_target.id) THEN
    RETURN json_build_object('success', false, 'message', 'Staff is not in your network');
  END IF;

  UPDATE public.business_staff
  SET is_active = false, updated_at = now()
  WHERE id = v_target.id;

  RETURN json_build_object(
    'success', true,
    'staff_id', v_target.id,
    'role', v_role
  );
END;
$function$;

-- =============================================================================
-- 3. Super BD deactivate agency sponsored in subtree
-- =============================================================================

CREATE OR REPLACE FUNCTION public.super_bd_deactivate_agency(p_agency_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_me public.business_staff%ROWTYPE;
  v_agency public.agencies%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_me
  FROM public.business_staff
  WHERE user_id = v_uid AND is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_me.id IS NULL OR public.normalize_staff_role(v_me.role) <> 'super_bd' THEN
    RETURN json_build_object('success', false, 'message', 'Only Super Admin can deactivate agencies');
  END IF;

  SELECT * INTO v_agency
  FROM public.agencies
  WHERE id = p_agency_id;

  IF v_agency.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Agency not found');
  END IF;

  IF NOT COALESCE(v_agency.is_active, false) THEN
    RETURN json_build_object('success', false, 'message', 'Agency already inactive');
  END IF;

  IF v_agency.sponsor_staff_id IS NULL
     OR NOT (
       v_agency.sponsor_staff_id = v_me.id
       OR public.is_staff_descendant(v_me.id, v_agency.sponsor_staff_id)
     )
  THEN
    RETURN json_build_object('success', false, 'message', 'Agency is not in your network');
  END IF;

  UPDATE public.agencies
  SET is_active = false
  WHERE id = v_agency.id;

  RETURN json_build_object(
    'success', true,
    'agency_id', v_agency.id
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_business_staff(uuid, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.super_bd_deactivate_staff(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.super_bd_deactivate_agency(uuid) TO authenticated;
