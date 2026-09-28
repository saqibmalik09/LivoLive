-- Super Admin limited: ban/unban users in subtree only (no PII edit)

CREATE OR REPLACE FUNCTION public.super_bd_set_user_banned(
  p_target_user_id uuid,
  p_banned boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff public.business_staff%ROWTYPE;
  v_in_subtree boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_staff FROM public.business_staff
  WHERE user_id = v_uid AND is_active AND role = 'super_bd'
  LIMIT 1;

  IF v_staff.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Super Admin only');
  END IF;

  -- Target in subtree: staff under SA, or host/owner of agency sponsored by subtree BD
  IF EXISTS (
    SELECT 1 FROM public.business_staff bs
    WHERE bs.user_id = p_target_user_id AND bs.is_active
      AND (
        bs.parent_staff_id = v_staff.id
        OR public.is_staff_descendant(v_staff.id, bs.id)
      )
  ) THEN
    v_in_subtree := true;
  END IF;

  IF NOT v_in_subtree AND EXISTS (
    SELECT 1
    FROM public.agency_members am
    JOIN public.agencies a ON a.id = am.agency_id
    JOIN public.business_staff bd ON bd.id = a.sponsor_staff_id
    WHERE am.user_id = p_target_user_id
      AND (
        bd.parent_staff_id IN (
          SELECT id FROM public.business_staff WHERE parent_staff_id = v_staff.id AND is_active
        )
        OR bd.id IN (
          SELECT id FROM public.business_staff WHERE parent_staff_id = v_staff.id AND is_active
        )
        OR public.is_staff_descendant(v_staff.id, bd.id)
      )
  ) THEN
    v_in_subtree := true;
  END IF;

  IF NOT v_in_subtree THEN
    RETURN json_build_object('success', false, 'message', 'User not in your team subtree');
  END IF;

  UPDATE public.users SET is_banned = p_banned WHERE id = p_target_user_id;

  RETURN json_build_object('success', true, 'user_id', p_target_user_id, 'is_banned', p_banned);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.super_bd_set_user_banned(uuid, boolean) TO authenticated;
