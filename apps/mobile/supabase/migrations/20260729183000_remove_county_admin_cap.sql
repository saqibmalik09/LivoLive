-- Remove Super Admin hard cap on County Admins (was max 2).
-- Assistant (2) and Customer Service (4) caps unchanged.

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
      -- County Admin / BD under Super Admin: no hard cap
      IF v_role = 'assistant' AND v_count >= 2 THEN
        RETURN json_build_object('success', false, 'message', 'Max 2 Assistants per Super Admin');
      END IF;
      IF v_role = 'customer_service' AND v_count >= 4 THEN
        RETURN json_build_object('success', false, 'message', 'Max 4 Customer Service per Super Admin');
      END IF;
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

GRANT EXECUTE ON FUNCTION public.create_business_staff(uuid, text, uuid, uuid) TO authenticated;
