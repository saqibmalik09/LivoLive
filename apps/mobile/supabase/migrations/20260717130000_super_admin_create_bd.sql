-- Allow Super Admin (super_bd) to create both BD Admin and BD under themselves.

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
    v_creator_staff public.business_staff%ROWTYPE;
    v_expected_child text;
    v_new_id uuid;
    v_code text;
BEGIN
    IF p_role NOT IN ('super_bd', 'bd_admin', 'bd') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid role');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.business_staff
        WHERE user_id = p_target_user_id AND is_active = true
    ) THEN
        RETURN json_build_object('success', false, 'message', 'User already has an active staff role');
    END IF;

    IF p_role = 'super_bd' THEN
        IF p_parent_staff_id IS NOT NULL THEN
            RETURN json_build_object('success', false, 'message', 'Super Admin cannot have a parent staff');
        END IF;
    ELSE
        IF p_parent_staff_id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Parent staff is required');
        END IF;

        SELECT * INTO v_creator_staff
        FROM public.business_staff
        WHERE id = p_parent_staff_id AND is_active = true;

        IF v_creator_staff.id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Parent staff not found');
        END IF;

        -- Super Admin may create BD Admin or BD directly.
        IF v_creator_staff.role = 'super_bd' THEN
            IF p_role NOT IN ('bd_admin', 'bd') THEN
                RETURN json_build_object(
                    'success', false,
                    'message', 'Super Admin can only create BD Admin or BD'
                );
            END IF;
        ELSE
            v_expected_child := public.business_staff_child_role(v_creator_staff.role);
            IF v_expected_child IS DISTINCT FROM p_role THEN
                RETURN json_build_object(
                    'success', false,
                    'message', format('Parent role %s cannot create %s', v_creator_staff.role, p_role)
                );
            END IF;
        END IF;
    END IF;

    v_code := public.generate_staff_code();

    INSERT INTO public.business_staff (
        user_id, role, parent_staff_id, staff_code, created_by_user_id
    )
    VALUES (
        p_target_user_id,
        p_role,
        CASE WHEN p_role = 'super_bd' THEN NULL ELSE p_parent_staff_id END,
        v_code,
        p_created_by_user_id
    )
    RETURNING id INTO v_new_id;

    RETURN json_build_object(
        'success', true,
        'staff_id', v_new_id,
        'staff_code', v_code,
        'role', p_role
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_business_staff(uuid, text, uuid, uuid) TO authenticated;
