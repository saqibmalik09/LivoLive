-- Room decorations: catalog pricing + custom user background price + secure coin deduction.

ALTER TABLE public.room_decorations
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;

INSERT INTO public.system_settings (key, value, description)
VALUES (
  'room_custom_background_price',
  '500',
  'Coins charged when a host uploads and applies their own room background image'
)
ON CONFLICT (key) DO NOTHING;

-- Storage for admin catalog images and user-uploaded backgrounds
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'room_backgrounds',
  'room_backgrounds',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[]
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read room_backgrounds" ON storage.objects;
CREATE POLICY "Public read room_backgrounds"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'room_backgrounds');

DROP POLICY IF EXISTS "Authenticated upload own room_backgrounds" ON storage.objects;
CREATE POLICY "Authenticated upload own room_backgrounds"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'room_backgrounds'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Authenticated update own room_backgrounds" ON storage.objects;
CREATE POLICY "Authenticated update own room_backgrounds"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'room_backgrounds'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE OR REPLACE FUNCTION public.get_room_custom_background_price()
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(trim(value), '')::integer,
    500
  )
  FROM public.system_settings
  WHERE key = 'room_custom_background_price'
  LIMIT 1;
$$;

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

  SELECT image_url, COALESCE(is_premium, false), COALESCE(price, 0)
  INTO v_image_url, v_is_premium, v_price
  FROM public.room_decorations
  WHERE id = p_decoration_id AND COALESCE(is_active, true) = true;

  IF v_image_url IS NULL THEN
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
  SET decoration_id = p_decoration_id, background_url = v_image_url
  WHERE id = p_room_id;

  RETURN json_build_object(
    'success', true,
    'background_url', v_image_url,
    'coins_charged', CASE WHEN v_is_premium AND v_price > 0 THEN v_price ELSE 0 END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_room_custom_background(
  p_room_id uuid,
  p_background_url text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_price integer;
  v_balance bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_background_url IS NULL OR length(trim(p_background_url)) < 10 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid background URL');
  END IF;

  SELECT host_id INTO v_host_id FROM public.rooms WHERE id = p_room_id;
  IF v_host_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;
  IF v_host_id <> v_user_id THEN
    RETURN json_build_object('success', false, 'message', 'Only the room host can change decoration');
  END IF;

  v_price := public.get_room_custom_background_price();

  IF v_price > 0 THEN
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
      'Room decoration: custom background',
      p_room_id
    );
  END IF;

  UPDATE public.rooms
  SET decoration_id = NULL, background_url = trim(p_background_url)
  WHERE id = p_room_id;

  RETURN json_build_object(
    'success', true,
    'background_url', trim(p_background_url),
    'coins_charged', v_price
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_room_decoration(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_room_custom_background(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_room_custom_background_price() TO authenticated, anon;
