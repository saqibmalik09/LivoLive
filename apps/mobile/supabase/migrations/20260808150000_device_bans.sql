-- Device-level bans: install UUID stored on the phone, registered after login.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_device_id text,
  ADD COLUMN IF NOT EXISTS last_device_at timestamptz;

CREATE INDEX IF NOT EXISTS users_last_device_id_idx
  ON public.users (last_device_id)
  WHERE last_device_id IS NOT NULL;

COMMENT ON COLUMN public.users.last_device_id IS
  'Last app installation device id reported by the mobile client.';
COMMENT ON COLUMN public.users.last_device_at IS
  'When last_device_id was last registered.';

CREATE TABLE IF NOT EXISTS public.banned_devices (
  device_id text PRIMARY KEY,
  reason text,
  banned_at timestamptz NOT NULL DEFAULT now(),
  banned_by uuid,
  last_user_id uuid REFERENCES public.users (id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE public.banned_devices IS
  'Device install IDs blocked from using the app (any account).';

CREATE INDEX IF NOT EXISTS banned_devices_active_idx
  ON public.banned_devices (device_id)
  WHERE is_active;

ALTER TABLE public.banned_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS banned_devices_no_client ON public.banned_devices;
CREATE POLICY banned_devices_no_client
  ON public.banned_devices
  FOR ALL
  TO authenticated, anon
  USING (false)
  WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.register_my_device(p_device_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_reason text;
  v_id text := NULLIF(trim(COALESCE(p_device_id, '')), '');
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'banned', false, 'message', 'Not authenticated');
  END IF;

  IF v_id IS NULL OR char_length(v_id) < 8 OR char_length(v_id) > 128 THEN
    RETURN json_build_object('success', false, 'banned', false, 'message', 'Invalid device id');
  END IF;

  SELECT bd.reason INTO v_reason
  FROM public.banned_devices bd
  WHERE bd.device_id = v_id AND bd.is_active
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.banned_devices
    SET last_user_id = v_uid
    WHERE device_id = v_id AND is_active;

    RETURN json_build_object(
      'success', false,
      'banned', true,
      'reason', v_reason,
      'message', 'Device is banned'
    );
  END IF;

  UPDATE public.users
  SET
    last_device_id = v_id,
    last_device_at = now()
  WHERE id = v_uid;

  RETURN json_build_object(
    'success', true,
    'banned', false,
    'device_id', v_id
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.register_my_device(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.check_device_banned(p_device_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_reason text;
  v_id text := NULLIF(trim(COALESCE(p_device_id, '')), '');
BEGIN
  IF v_id IS NULL THEN
    RETURN json_build_object('banned', false);
  END IF;

  SELECT bd.reason INTO v_reason
  FROM public.banned_devices bd
  WHERE bd.device_id = v_id AND bd.is_active
  LIMIT 1;

  IF FOUND THEN
    RETURN json_build_object('banned', true, 'reason', v_reason);
  END IF;

  RETURN json_build_object('banned', false);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.check_device_banned(text) TO authenticated, anon;
