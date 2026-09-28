-- Gateway / service DB connections have auth.uid() = NULL.
-- Mute privacy must only block *client* admins from unmuting others,
-- not the trusted realtime gateway writing on the seated user's behalf.

CREATE OR REPLACE FUNCTION public.enforce_room_seat_mute_privacy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- No JWT / server role → allow (gateway seat:mute).
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

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
