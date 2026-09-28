-- Allow invitee to become sub-admin when they accept a pending admin invitation.
-- Regression: 20260807180000 made enforce_room_member_role_change deny-by-default
-- and only allowed self admin→member resign. Accept path runs as the invitee
-- (auth.uid = invitee) while handle_room_admin_invitation updates member→admin,
-- which then raised: Not allowed to change room member role (42501).

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

  -- Invitee completing an accepted sub-admin invitation (member -> admin).
  -- handle_room_admin_invitation runs as SECURITY DEFINER but auth.uid() stays
  -- the invitee, so this path must be allowed explicitly.
  IF v_is_self
     AND OLD.role = 'member'
     AND NEW.role = 'admin'
     AND EXISTS (
       SELECT 1
         FROM public.room_invitations ri
        WHERE ri.room_id = NEW.room_id
          AND ri.invitee_id = NEW.user_id
          AND ri.role = 'admin'
          AND ri.status = 'accepted'
     ) THEN
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
