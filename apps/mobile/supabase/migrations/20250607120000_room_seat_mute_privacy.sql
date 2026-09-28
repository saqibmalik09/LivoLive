-- Privacy: room host/admin may mute others' mics, but cannot unmute them.
-- Only the seated user may turn their own mic on (is_muted = false).

DROP POLICY IF EXISTS "Authenticated users can manage seats" ON public.room_seats;

CREATE OR REPLACE FUNCTION public.enforce_room_seat_mute_privacy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.user_id IS NOT NULL
     AND auth.uid() IS DISTINCT FROM NEW.user_id
     AND COALESCE(OLD.is_muted, false) = true
     AND COALESCE(NEW.is_muted, false) = false THEN
    RAISE EXCEPTION 'Only the seated user can unmute their microphone'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS room_seats_mute_privacy ON public.room_seats;

CREATE TRIGGER room_seats_mute_privacy
  BEFORE UPDATE OF is_muted ON public.room_seats
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_room_seat_mute_privacy();
