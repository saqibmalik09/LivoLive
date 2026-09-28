-- Allow platform Super Admins (business_staff.role = super_bd) to occupy locked seats.

CREATE OR REPLACE FUNCTION public.enforce_room_seat_lock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  occupying boolean;
  is_super_admin boolean;
BEGIN
  occupying := (TG_OP = 'INSERT' AND NEW.user_id IS NOT NULL)
    OR (
      TG_OP = 'UPDATE'
      AND NEW.user_id IS NOT NULL
      AND (
        OLD.user_id IS DISTINCT FROM NEW.user_id
        OR OLD.seat_index IS DISTINCT FROM NEW.seat_index
      )
    );

  IF occupying THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.business_staff bs
      WHERE bs.user_id = NEW.user_id
        AND bs.is_active = true
        AND bs.role = 'super_bd'
    ) INTO is_super_admin;

    IF COALESCE(NEW.is_locked, false) = true AND NOT is_super_admin THEN
      RAISE EXCEPTION 'Seat is locked';
    END IF;

    IF NOT is_super_admin AND EXISTS (
      SELECT 1
      FROM public.room_seats rs
      WHERE rs.room_id = NEW.room_id
        AND rs.seat_index = NEW.seat_index
        AND rs.is_locked = true
        AND rs.id IS DISTINCT FROM NEW.id
    ) THEN
      RAISE EXCEPTION 'Seat is locked';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
