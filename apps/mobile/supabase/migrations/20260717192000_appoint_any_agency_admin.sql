-- Allow appointing any user as agency admin (not only existing hosts)

CREATE OR REPLACE FUNCTION public.set_agency_member_role(
  p_agency_id uuid,
  p_user_id uuid,
  p_role text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_role IS NULL OR p_role NOT IN ('host', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid role');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.agencies WHERE id = p_agency_id AND owner_id = v_uid
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Only owner can change roles');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.agencies WHERE id = p_agency_id AND owner_id = p_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Cannot change President role');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  -- Appoint admin: insert if not a member yet, else update role
  IF p_role = 'admin' THEN
    IF EXISTS (
      SELECT 1 FROM public.agency_members
      WHERE agency_id = p_agency_id AND user_id = p_user_id
    ) THEN
      UPDATE public.agency_members
      SET role = 'admin'
      WHERE agency_id = p_agency_id AND user_id = p_user_id;
    ELSE
      INSERT INTO public.agency_members (agency_id, user_id, role)
      VALUES (p_agency_id, p_user_id, 'admin');
    END IF;

    RETURN json_build_object('success', true, 'message', 'Admin appointed', 'role', 'admin');
  END IF;

  -- Demote admin -> host (must already be a member)
  UPDATE public.agency_members
  SET role = 'host'
  WHERE agency_id = p_agency_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Member not found');
  END IF;

  RETURN json_build_object('success', true, 'message', 'Admin removed', 'role', 'host');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_agency_member_role(uuid, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
