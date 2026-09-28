-- Room shared audio (device music for all members), synced like YouTube watch party.

ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS shared_audio_state jsonb NOT NULL DEFAULT '{
    "is_active": false,
    "audio_url": "",
    "title": "",
    "status": "stopped",
    "timestamp": 0,
    "duration": 0,
    "updated_at": null,
    "started_by": null,
    "started_by_name": ""
  }'::jsonb;

CREATE OR REPLACE FUNCTION public.update_room_shared_audio_state(
  p_room_id uuid,
  p_shared_audio_state jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.rooms WHERE id = p_room_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.rooms
  SET shared_audio_state = p_shared_audio_state
  WHERE id = p_room_id;

  RETURN p_shared_audio_state;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_room_shared_audio_state(uuid, jsonb) TO authenticated;
