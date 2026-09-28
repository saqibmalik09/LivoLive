-- Multi-signal device bans: install UUID + ANDROID_ID + FCM token.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_android_id text;

CREATE INDEX IF NOT EXISTS users_last_android_id_idx
  ON public.users (last_android_id)
  WHERE last_android_id IS NOT NULL;

COMMENT ON COLUMN public.users.last_android_id IS
  'Last Android Settings.Secure.ANDROID_ID (or iOS identifierForVendor) reported by the app.';

CREATE TABLE IF NOT EXISTS public.banned_device_signals (
  signal_type text NOT NULL
    CHECK (signal_type = ANY (ARRAY['install_id'::text, 'android_id'::text, 'fcm_token'::text])),
  signal_value text NOT NULL,
  reason text,
  banned_at timestamptz NOT NULL DEFAULT now(),
  banned_by uuid,
  last_user_id uuid REFERENCES public.users (id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (signal_type, signal_value)
);

COMMENT ON TABLE public.banned_device_signals IS
  'Device ban fingerprints: install UUID, hardware ANDROID_ID, and FCM push token.';

CREATE INDEX IF NOT EXISTS banned_device_signals_active_idx
  ON public.banned_device_signals (signal_type, signal_value)
  WHERE is_active;

ALTER TABLE public.banned_device_signals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS banned_device_signals_no_client ON public.banned_device_signals;
CREATE POLICY banned_device_signals_no_client
  ON public.banned_device_signals
  FOR ALL
  TO authenticated, anon
  USING (false)
  WITH CHECK (false);

-- Copy existing install bans into the new signals table.
INSERT INTO public.banned_device_signals (
  signal_type, signal_value, reason, banned_at, banned_by, last_user_id, is_active
)
SELECT
  'install_id',
  bd.device_id,
  bd.reason,
  bd.banned_at,
  bd.banned_by,
  bd.last_user_id,
  bd.is_active
FROM public.banned_devices bd
ON CONFLICT (signal_type, signal_value) DO NOTHING;

CREATE OR REPLACE FUNCTION public._device_signal_banned(
  p_install_id text,
  p_android_id text,
  p_fcm_token text
)
RETURNS TABLE (out_reason text, out_matched_type text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_install text := NULLIF(trim(COALESCE(p_install_id, '')), '');
  v_android text := NULLIF(trim(COALESCE(p_android_id, '')), '');
  v_fcm text := NULLIF(trim(COALESCE(p_fcm_token, '')), '');
  v_reason text;
  v_matched text;
BEGIN
  SELECT s.reason, s.signal_type
  INTO v_reason, v_matched
  FROM public.banned_device_signals s
  WHERE s.is_active
    AND (
      (v_install IS NOT NULL AND s.signal_type = 'install_id' AND s.signal_value = v_install)
      OR (v_android IS NOT NULL AND char_length(v_android) >= 8
          AND s.signal_type = 'android_id' AND s.signal_value = v_android)
      OR (v_fcm IS NOT NULL AND char_length(v_fcm) >= 20
          AND s.signal_type = 'fcm_token' AND s.signal_value = v_fcm)
    )
  ORDER BY
    CASE s.signal_type
      WHEN 'android_id' THEN 1
      WHEN 'install_id' THEN 2
      ELSE 3
    END
  LIMIT 1;

  IF FOUND THEN
    out_reason := v_reason;
    out_matched_type := v_matched;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Legacy table fallback (install UUID only)
  IF v_install IS NOT NULL THEN
    SELECT bd.reason, 'install_id'::text
    INTO v_reason, v_matched
    FROM public.banned_devices bd
    WHERE bd.device_id = v_install AND bd.is_active
    LIMIT 1;

    IF FOUND THEN
      out_reason := v_reason;
      out_matched_type := v_matched;
      RETURN NEXT;
    END IF;
  END IF;
END;
$function$;

DROP FUNCTION IF EXISTS public.register_my_device(text);
DROP FUNCTION IF EXISTS public.register_my_device(text, text, text);

CREATE OR REPLACE FUNCTION public.register_my_device(
  p_device_id text,
  p_android_id text DEFAULT NULL,
  p_fcm_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_install text := NULLIF(trim(COALESCE(p_device_id, '')), '');
  v_android text := NULLIF(trim(COALESCE(p_android_id, '')), '');
  v_fcm text := NULLIF(trim(COALESCE(p_fcm_token, '')), '');
  v_reason text;
  v_matched text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'banned', false, 'message', 'Not authenticated');
  END IF;

  IF v_install IS NULL OR char_length(v_install) < 8 OR char_length(v_install) > 128 THEN
    RETURN json_build_object('success', false, 'banned', false, 'message', 'Invalid device id');
  END IF;

  SELECT h.out_reason, h.out_matched_type
  INTO v_reason, v_matched
  FROM public._device_signal_banned(v_install, v_android, v_fcm) h
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.banned_device_signals
    SET last_user_id = v_uid
    WHERE is_active
      AND (
        (signal_type = 'install_id' AND signal_value = v_install)
        OR (v_android IS NOT NULL AND signal_type = 'android_id' AND signal_value = v_android)
        OR (v_fcm IS NOT NULL AND signal_type = 'fcm_token' AND signal_value = v_fcm)
      );

    UPDATE public.banned_devices
    SET last_user_id = v_uid
    WHERE device_id = v_install AND is_active;

    RETURN json_build_object(
      'success', false,
      'banned', true,
      'reason', v_reason,
      'matched', v_matched,
      'message', 'Device is banned'
    );
  END IF;

  UPDATE public.users
  SET
    last_device_id = v_install,
    last_android_id = COALESCE(v_android, last_android_id),
    last_device_at = now(),
    fcm_token = COALESCE(v_fcm, fcm_token)
  WHERE id = v_uid;

  RETURN json_build_object(
    'success', true,
    'banned', false,
    'device_id', v_install,
    'android_id', v_android
  );
END;
$function$;

DROP FUNCTION IF EXISTS public.check_device_banned(text);
DROP FUNCTION IF EXISTS public.check_device_banned(text, text, text);

CREATE OR REPLACE FUNCTION public.check_device_banned(
  p_device_id text,
  p_android_id text DEFAULT NULL,
  p_fcm_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_reason text;
  v_matched text;
BEGIN
  SELECT h.out_reason, h.out_matched_type
  INTO v_reason, v_matched
  FROM public._device_signal_banned(p_device_id, p_android_id, p_fcm_token) h
  LIMIT 1;

  IF FOUND THEN
    RETURN json_build_object(
      'banned', true,
      'reason', v_reason,
      'matched', v_matched
    );
  END IF;

  RETURN json_build_object('banned', false);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.register_my_device(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_device_banned(text, text, text) TO authenticated, anon;
