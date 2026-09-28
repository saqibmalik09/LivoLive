-- Prevent users from occupying locked seats (placeholder or locked flag on row).

CREATE OR REPLACE FUNCTION public.enforce_room_seat_lock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  occupying boolean;
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
    IF COALESCE(NEW.is_locked, false) = true THEN
      RAISE EXCEPTION 'Seat is locked';
    END IF;

    IF EXISTS (
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

DROP TRIGGER IF EXISTS room_seats_lock_enforce ON public.room_seats;

CREATE TRIGGER room_seats_lock_enforce
  BEFORE INSERT OR UPDATE OF user_id, seat_index, is_locked
  ON public.room_seats
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_room_seat_lock();
