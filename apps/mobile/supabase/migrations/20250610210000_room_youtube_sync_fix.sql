-- Allow host OR room admin to persist YouTube watch-party state for all members.

CREATE OR REPLACE FUNCTION public.update_room_youtube_state(
  p_room_id uuid,
  p_youtube_state jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_is_admin boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT host_id
  INTO v_host_id
  FROM public.rooms
  WHERE id = p_room_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  v_is_admin := EXISTS (
    SELECT 1
    FROM public.room_members rm
    WHERE rm.room_id = p_room_id
      AND rm.user_id = v_user_id
      AND rm.role = 'admin'
  );

  IF v_user_id <> v_host_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Only host or room admin can control YouTube'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.rooms
  SET youtube_state = p_youtube_state
  WHERE id = p_room_id;

  RETURN p_youtube_state;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_room_youtube_state(uuid, jsonb) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'rooms'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
  END IF;
END $$;
