-- Super BD portal: gate RPC + grants

GRANT EXECUTE ON FUNCTION public.get_my_super_bd_staff_id() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_staff_gate_info()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_profile record;
    v_staff record;
    v_super_id uuid;
BEGIN
    IF v_uid IS NULL THEN
        RETURN json_build_object('authenticated', false);
    END IF;

    SELECT username, short_id INTO v_profile
    FROM public.users WHERE id = v_uid;

    SELECT role, staff_code, is_active INTO v_staff
    FROM public.business_staff
    WHERE user_id = v_uid AND is_active = true
    ORDER BY created_at DESC
    LIMIT 1;

    v_super_id := public.get_my_super_bd_staff_id();

    RETURN json_build_object(
        'authenticated', true,
        'user_id', v_uid,
        'username', v_profile.username,
        'short_id', v_profile.short_id,
        'staff_role', v_staff.role,
        'staff_code', v_staff.staff_code,
        'is_super_bd', v_super_id IS NOT NULL,
        'super_bd_staff_id', v_super_id
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_my_staff_gate_info() TO authenticated;
