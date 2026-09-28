-- Seat invitations: admin invites user to sit (in-room popup + notification if away).

ALTER TABLE public.room_invitations
  DROP CONSTRAINT IF EXISTS room_invitations_role_check;

ALTER TABLE public.room_invitations
  ADD CONSTRAINT room_invitations_role_check CHECK (role IN ('admin', 'seat'));

ALTER TABLE public.room_invitations
  ADD COLUMN IF NOT EXISTS seat_index integer;

CREATE OR REPLACE FUNCTION public.find_available_room_seat(p_room_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_mic_count integer;
  i integer;
BEGIN
  SELECT COALESCE(mic_count, 8) INTO v_mic_count FROM public.rooms WHERE id = p_room_id;
  FOR i IN 0..(v_mic_count - 1) LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.room_seats rs
      WHERE rs.room_id = p_room_id
        AND rs.seat_index = i
        AND (rs.user_id IS NOT NULL OR COALESCE(rs.is_locked, false) = true)
    ) THEN
      RETURN i;
    END IF;
  END LOOP;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_accepted_seat_invitation(p_inv public.room_invitations)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seat_idx integer;
  v_row_id uuid;
BEGIN
  v_seat_idx := p_inv.seat_index;
  IF v_seat_idx IS NULL THEN
    v_seat_idx := public.find_available_room_seat(p_inv.room_id);
  END IF;

  IF v_seat_idx IS NULL THEN
    RAISE EXCEPTION 'No available seat in this room';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.room_seats
    WHERE room_id = p_inv.room_id
      AND seat_index = v_seat_idx
      AND COALESCE(is_locked, false) = true
  ) THEN
    RAISE EXCEPTION 'Seat is locked';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.room_seats
    WHERE room_id = p_inv.room_id
      AND seat_index = v_seat_idx
      AND user_id IS NOT NULL
      AND user_id IS DISTINCT FROM p_inv.invitee_id
  ) THEN
    RAISE EXCEPTION 'Seat is already taken';
  END IF;

  DELETE FROM public.room_seats
  WHERE room_id = p_inv.room_id AND user_id = p_inv.invitee_id;

  SELECT id INTO v_row_id
  FROM public.room_seats
  WHERE room_id = p_inv.room_id AND seat_index = v_seat_idx
  LIMIT 1;

  IF v_row_id IS NOT NULL THEN
    UPDATE public.room_seats
    SET user_id = p_inv.invitee_id, is_muted = true, is_locked = false
    WHERE id = v_row_id;
  ELSE
    INSERT INTO public.room_seats (room_id, user_id, seat_index, is_muted, is_locked)
    VALUES (p_inv.room_id, p_inv.invitee_id, v_seat_idx, true, false);
  END IF;
END;
$$;

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
  v_seat_label text;
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

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' AND NEW.role = 'seat' THEN
    v_seat_label := CASE
      WHEN NEW.seat_index IS NOT NULL THEN format('seat %s', NEW.seat_index + 1)
      ELSE 'a mic seat'
    END;

    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.invitee_id,
      'Seat Invitation',
      format('%s invited you to sit on %s in room "%s". Tap to accept or decline.', v_inviter_name, v_seat_label, v_room_title),
      'room_seat_invite',
      'seat',
      jsonb_build_object(
        'invitation_id', NEW.id,
        'room_id', NEW.room_id,
        'seat_index', NEW.seat_index
      )
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

  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' AND NEW.role = 'seat' THEN
    PERFORM public.apply_accepted_seat_invitation(NEW);

    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.inviter_id,
      'Seat Invitation Accepted',
      format('%s accepted your seat invitation in "%s".', v_invitee_name, v_room_title),
      'room_seat_accepted',
      'seat',
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

  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'rejected' AND NEW.role = 'seat' THEN
    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.inviter_id,
      'Seat Invitation Declined',
      format('%s declined your seat invitation in "%s".', v_invitee_name, v_room_title),
      'room_seat_rejected',
      'seat',
      jsonb_build_object('invitation_id', NEW.id, 'room_id', NEW.room_id)
    );
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;
