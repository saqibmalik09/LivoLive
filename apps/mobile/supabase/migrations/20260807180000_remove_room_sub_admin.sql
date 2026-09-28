-- Fix room sub-admin remove: host can demote; admin can resign; clear RPC.

CREATE OR REPLACE FUNCTION public.enforce_room_member_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_room_host uuid;
  v_is_host boolean;
  v_is_room_admin boolean;
  v_is_super_bd boolean;
  v_is_self boolean;
BEGIN
  IF TG_OP <> 'UPDATE' OR OLD.role IS NOT DISTINCT FROM NEW.role THEN
    RETURN NEW;
  END IF;

  SELECT host_id INTO v_room_host FROM public.rooms WHERE id = NEW.room_id;
  v_is_host := (auth.uid() = v_room_host);
  v_is_super_bd := public.is_active_super_bd(auth.uid());
  v_is_self := (auth.uid() = NEW.user_id);
  v_is_room_admin := EXISTS (
    SELECT 1 FROM public.room_members rm
    WHERE rm.room_id = NEW.room_id
      AND rm.user_id = auth.uid()
      AND rm.role = 'admin'
  );

  IF NEW.user_id = v_room_host OR OLD.role = 'host' OR NEW.role = 'host' THEN
    RAISE EXCEPTION 'Cannot change the host role' USING ERRCODE = '42501';
  END IF;

  -- Host / Super BD: may promote or demote freely (except host role above).
  IF v_is_host OR v_is_super_bd THEN
    RETURN NEW;
  END IF;

  -- Self resign: admin -> member
  IF v_is_self AND OLD.role = 'admin' AND NEW.role = 'member' THEN
    RETURN NEW;
  END IF;

  -- Other room admins: only promote member -> admin
  IF v_is_room_admin THEN
    IF OLD.role = 'member' AND NEW.role = 'admin' THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Room admins can only promote members to sub-admin'
      USING ERRCODE = '42501';
  END IF;

  RAISE EXCEPTION 'Not allowed to change room member role' USING ERRCODE = '42501';
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_room_sub_admin(
  p_room_id uuid,
  p_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_host_id uuid;
  v_role text;
  v_is_super_bd boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid params');
  END IF;

  SELECT host_id INTO v_host_id FROM public.rooms WHERE id = p_room_id;
  IF v_host_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  IF p_user_id = v_host_id THEN
    RETURN json_build_object('success', false, 'message', 'Cannot remove the room owner');
  END IF;

  v_is_super_bd := public.is_active_super_bd(v_uid);

  IF v_uid <> v_host_id AND v_uid <> p_user_id AND NOT v_is_super_bd THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Only the room owner can remove a sub-admin'
    );
  END IF;

  SELECT role INTO v_role
  FROM public.room_members
  WHERE room_id = p_room_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User is not a room member');
  END IF;

  IF v_role <> 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'User is not a sub-admin');
  END IF;

  UPDATE public.room_members
  SET role = 'member'
  WHERE room_id = p_room_id
    AND user_id = p_user_id
    AND role = 'admin';

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Remove failed');
  END IF;

  RETURN json_build_object(
    'success', true,
    'room_id', p_room_id,
    'user_id', p_user_id,
    'role', 'member'
  );
EXCEPTION
  WHEN others THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_room_sub_admin(uuid, uuid)
  TO authenticated, service_role;
