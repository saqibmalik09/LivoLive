-- Safer stale seat cleanup: never wipe all seats when online list is empty,
-- and skip rows updated in the last 30s (presence lag race).

ALTER TABLE public.room_seats
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION public.cleanup_stale_room_seats(
  p_room_id uuid,
  p_online_user_ids uuid[]
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  IF p_room_id IS NULL THEN
    RETURN 0;
  END IF;

  -- Empty presence list must not delete every seated user.
  IF p_online_user_ids IS NULL OR cardinality(p_online_user_ids) = 0 THEN
    RETURN 0;
  END IF;

  DELETE FROM public.room_seats
  WHERE room_id = p_room_id
    AND user_id IS NOT NULL
    AND NOT (user_id = ANY(p_online_user_ids))
    AND COALESCE(updated_at, now()) < now() - INTERVAL '30 seconds';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

CREATE OR REPLACE FUNCTION public.room_seats_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS room_seats_set_updated_at ON public.room_seats;

CREATE TRIGGER room_seats_set_updated_at
  BEFORE INSERT OR UPDATE ON public.room_seats
  FOR EACH ROW
  EXECUTE FUNCTION public.room_seats_touch_updated_at();

GRANT EXECUTE ON FUNCTION public.cleanup_stale_room_seats(uuid, uuid[]) TO authenticated;
