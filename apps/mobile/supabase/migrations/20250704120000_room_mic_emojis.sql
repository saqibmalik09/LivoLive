-- Room mic emojis: catalog + send RPC (free + premium VIP-only)

CREATE TABLE IF NOT EXISTS public.room_mic_emojis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  image_url text NOT NULL,
  svga_url text,
  is_premium boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_room_mic_emojis_active_sort
  ON public.room_mic_emojis (is_active, sort_order, created_at);

ALTER TABLE public.room_mic_emojis ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS room_mic_emojis_select_active ON public.room_mic_emojis;
CREATE POLICY room_mic_emojis_select_active
  ON public.room_mic_emojis
  FOR SELECT
  TO authenticated, anon
  USING (is_active = true);

CREATE OR REPLACE FUNCTION public.room_mic_emojis_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS room_mic_emojis_set_updated_at ON public.room_mic_emojis;
CREATE TRIGGER room_mic_emojis_set_updated_at
  BEFORE UPDATE ON public.room_mic_emojis
  FOR EACH ROW
  EXECUTE FUNCTION public.room_mic_emojis_touch_updated_at();

CREATE OR REPLACE FUNCTION public.send_room_mic_emoji(
  p_room_id uuid,
  p_emoji_id uuid,
  p_seat_index int
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_emoji public.room_mic_emojis%ROWTYPE;
  v_vip_level int;
  v_seat_user uuid;
  v_username text;
  v_avatar text;
  v_msg_id uuid;
  v_recent_count int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT rs.user_id
  INTO v_seat_user
  FROM public.room_seats rs
  WHERE rs.room_id = p_room_id
    AND rs.seat_index = p_seat_index;

  IF v_seat_user IS NULL OR v_seat_user <> v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'You must be on this seat to send emoji');
  END IF;

  SELECT *
  INTO v_emoji
  FROM public.room_mic_emojis
  WHERE id = p_emoji_id
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Emoji not found');
  END IF;

  IF v_emoji.is_premium THEN
    SELECT COALESCE(u.vip_level, 0)
    INTO v_vip_level
    FROM public.users u
    WHERE u.id = v_user_id;

    IF v_vip_level <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Premium emoji requires VIP');
    END IF;
  END IF;

  SELECT COUNT(*)
  INTO v_recent_count
  FROM public.room_messages rm
  WHERE rm.room_id = p_room_id
    AND rm.user_id = v_user_id
    AND rm.type = 'mic_emoji'
    AND rm.created_at > now() - interval '2 seconds';

  IF v_recent_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Please wait before sending another emoji');
  END IF;

  SELECT u.username, u.avatar_url
  INTO v_username, v_avatar
  FROM public.users u
  WHERE u.id = v_user_id;

  INSERT INTO public.room_messages (room_id, user_id, content, type, metadata)
  VALUES (
    p_room_id,
    v_user_id,
    '',
    'mic_emoji',
    jsonb_build_object(
      'emoji_id', p_emoji_id,
      'image_url', v_emoji.image_url,
      'svga_url', v_emoji.svga_url,
      'seat_index', p_seat_index,
      'sender_username', COALESCE(v_username, 'User'),
      'sender_avatar', v_avatar
    )
  )
  RETURNING id INTO v_msg_id;

  RETURN jsonb_build_object(
    'success', true,
    'message_id', v_msg_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_room_mic_emoji(uuid, uuid, int) TO authenticated;
