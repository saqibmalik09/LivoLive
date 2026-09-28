-- Sub-admin invite: notify invitee, on accept/reject notify inviter. No instant admin without accept.

ALTER TABLE public.system_notifications
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public.handle_room_admin_invitation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_room_title text;
  v_inviter_name text;
  v_invitee_name text;
BEGIN
  SELECT COALESCE(title, 'Room') INTO v_room_title FROM public.rooms WHERE id = NEW.room_id;
  SELECT COALESCE(username, 'User') INTO v_inviter_name FROM public.users WHERE id = NEW.inviter_id;
  SELECT COALESCE(username, 'User') INTO v_invitee_name FROM public.users WHERE id = NEW.invitee_id;

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' AND NEW.role = 'admin' THEN
    INSERT INTO public.room_members (room_id, user_id, role)
    VALUES (NEW.room_id, NEW.invitee_id, 'member')
    ON CONFLICT (room_id, user_id) DO NOTHING;

    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.invitee_id,
      'Sub-Admin Invitation',
      format('%s invited you to be Sub-Admin in room "%s". Tap to accept or decline.', v_inviter_name, v_room_title),
      'room_admin_invite',
      'admin',
      jsonb_build_object('invitation_id', NEW.id, 'room_id', NEW.room_id)
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' AND NEW.role = 'admin' THEN
    INSERT INTO public.room_members (room_id, user_id, role, joined_at)
    VALUES (NEW.room_id, NEW.invitee_id, 'admin', now())
    ON CONFLICT (room_id, user_id) DO UPDATE SET role = 'admin';

    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.inviter_id,
      'Sub-Admin Accepted',
      format('%s accepted your invitation. They are now Sub-Admin in "%s".', v_invitee_name, v_room_title),
      'room_admin_accepted',
      'admin',
      jsonb_build_object('invitation_id', NEW.id, 'room_id', NEW.room_id, 'invitee_id', NEW.invitee_id)
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'rejected' AND NEW.role = 'admin' THEN
    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.inviter_id,
      'Sub-Admin Declined',
      format('%s declined the Sub-Admin invitation for room "%s".', v_invitee_name, v_room_title),
      'room_admin_rejected',
      'admin',
      jsonb_build_object('invitation_id', NEW.id, 'room_id', NEW.room_id)
    );
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_room_admin_invitation ON public.room_invitations;
CREATE TRIGGER on_room_admin_invitation
  AFTER INSERT OR UPDATE OF status ON public.room_invitations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_room_admin_invitation();
