-- BD hierarchy follow-up: auth hardening, RLS for staff applications, commission defaults

UPDATE public.commission_configs
SET
    host_pc = 40,
    agency_pc = 10,
    bd_pc = COALESCE(bd_pc, 5),
    bd_admin_pc = COALESCE(bd_admin_pc, 3),
    super_bd_pc = COALESCE(super_bd_pc, 2),
    official_pc = 40,
    admin_pc = 40
WHERE id = 1;

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
    v_parent_staff public.business_staff%ROWTYPE;
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
            RETURN json_build_object('success', false, 'message', 'Super BD cannot have a parent staff');
        END IF;
        IF p_created_by_user_id IS NOT NULL THEN
            RETURN json_build_object('success', false, 'message', 'Super BD can only be created by Official');
        END IF;
    ELSE
        IF p_parent_staff_id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Parent staff is required');
        END IF;

        SELECT * INTO v_parent_staff
        FROM public.business_staff
        WHERE id = p_parent_staff_id AND is_active = true;

        IF v_parent_staff.id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Parent staff not found');
        END IF;

        v_expected_child := public.business_staff_child_role(v_parent_staff.role);
        IF v_expected_child IS DISTINCT FROM p_role THEN
            RETURN json_build_object(
                'success', false,
                'message', format('Parent role %s cannot create %s', v_parent_staff.role, p_role)
            );
        END IF;

        IF p_created_by_user_id IS NULL OR v_parent_staff.user_id <> p_created_by_user_id THEN
            RETURN json_build_object('success', false, 'message', 'Not authorized to create this staff member');
        END IF;
    END IF;

    v_code := public.generate_staff_code();

    INSERT INTO public.business_staff (
        user_id, role, parent_staff_id, staff_code, created_by_user_id
    )
    VALUES (
        p_target_user_id, p_role, p_parent_staff_id, v_code, p_created_by_user_id
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

DROP POLICY IF EXISTS "Staff read assigned agency applications" ON public.user_applications;
CREATE POLICY "Staff read assigned agency applications" ON public.user_applications
    FOR SELECT TO authenticated
    USING (
        type = 'agency'
        AND status = 'pending'
        AND target_staff_id IN (
            SELECT id FROM public.business_staff
            WHERE user_id = auth.uid() AND is_active = true
        )
    );
