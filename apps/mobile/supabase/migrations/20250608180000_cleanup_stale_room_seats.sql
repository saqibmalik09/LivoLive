-- Remove ghost seat occupants: users who left the room but still have a room_seats row.

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

  DELETE FROM public.room_seats
  WHERE room_id = p_room_id
    AND user_id IS NOT NULL
    AND NOT (user_id = ANY(COALESCE(p_online_user_ids, ARRAY[]::uuid[])));

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_stale_room_seats(uuid, uuid[]) TO authenticated;
