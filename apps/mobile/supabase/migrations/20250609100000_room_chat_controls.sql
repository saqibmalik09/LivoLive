-- Room chat moderation controls
-- chat_cleared_at : messages sent before this timestamp are hidden from clients
-- admin_only_chat : when true, only host/admin roles can send messages

ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS chat_cleared_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS admin_only_chat BOOLEAN NOT NULL DEFAULT FALSE;

-- RPC: clear chat for a room (sets chat_cleared_at = now())
CREATE OR REPLACE FUNCTION public.clear_room_chat(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.rooms
  SET chat_cleared_at = NOW()
  WHERE id = p_room_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_room_chat(UUID) TO authenticated;
