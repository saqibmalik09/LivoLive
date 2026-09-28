-- Allow SVGA-only or image-only room decorations (not both required).

ALTER TABLE public.room_decorations
  ADD COLUMN IF NOT EXISTS svga_url text;

ALTER TABLE public.room_decorations
  ALTER COLUMN image_url DROP NOT NULL;

UPDATE storage.buckets
SET
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'application/octet-stream'
  ]::text[]
WHERE id = 'room_backgrounds';

CREATE OR REPLACE FUNCTION public.apply_room_decoration(
  p_room_id uuid,
  p_decoration_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_price integer := 0;
  v_image_url text;
  v_svga_url text;
  v_background_url text;
  v_balance bigint;
  v_is_premium boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT host_id INTO v_host_id FROM public.rooms WHERE id = p_room_id;
  IF v_host_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;
  IF v_host_id <> v_user_id THEN
    RETURN json_build_object('success', false, 'message', 'Only the room host can change decoration');
  END IF;

  SELECT image_url, svga_url, COALESCE(is_premium, false), COALESCE(price, 0)
  INTO v_image_url, v_svga_url, v_is_premium, v_price
  FROM public.room_decorations
  WHERE id = p_decoration_id AND COALESCE(is_active, true) = true;

  v_background_url := COALESCE(
    NULLIF(trim(v_svga_url), ''),
    NULLIF(trim(v_image_url), '')
  );

  IF v_background_url IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Decoration not found');
  END IF;

  IF v_is_premium AND v_price > 0 THEN
    SELECT coins INTO v_balance FROM public.users WHERE id = v_user_id FOR UPDATE;
    IF v_balance < v_price THEN
      RETURN json_build_object('success', false, 'message', 'Insufficient coins', 'required_coins', v_price);
    END IF;

    UPDATE public.users SET coins = coins - v_price WHERE id = v_user_id;

    INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, description, reference_id)
    VALUES (
      v_user_id,
      v_price,
      'purchase',
      'coin',
      'Room decoration: catalog',
      p_decoration_id
    );
  END IF;

  UPDATE public.rooms
  SET decoration_id = p_decoration_id, background_url = v_background_url
  WHERE id = p_room_id;

  RETURN json_build_object(
    'success', true,
    'background_url', v_background_url,
    'coins_charged', CASE WHEN v_is_premium AND v_price > 0 THEN v_price ELSE 0 END
  );
END;
$$;
