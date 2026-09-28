-- Single-device login: when a user registers a new install device id,
-- revoke other auth sessions so the previous phone is logged out.

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
  v_prev_device text;
  v_keep_session uuid;
  v_kicked int := 0;
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

  SELECT last_device_id INTO v_prev_device
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;

  UPDATE public.users
  SET
    last_device_id = v_install,
    last_android_id = COALESCE(v_android, last_android_id),
    last_device_at = now(),
    fcm_token = COALESCE(v_fcm, fcm_token)
  WHERE id = v_uid;

  -- New phone / reinstall: keep only the newest auth session for this user.
  IF v_prev_device IS NOT NULL AND v_prev_device IS DISTINCT FROM v_install THEN
    SELECT s.id
    INTO v_keep_session
    FROM auth.sessions s
    WHERE s.user_id = v_uid
    ORDER BY COALESCE(s.refreshed_at, s.updated_at, s.created_at) DESC NULLS LAST
    LIMIT 1;

    IF v_keep_session IS NOT NULL THEN
      DELETE FROM auth.refresh_tokens rt
      WHERE rt.user_id = v_uid
        AND rt.session_id IS DISTINCT FROM v_keep_session;

      DELETE FROM auth.sessions s
      WHERE s.user_id = v_uid
        AND s.id IS DISTINCT FROM v_keep_session;

      GET DIAGNOSTICS v_kicked = ROW_COUNT;
    END IF;
  END IF;

  RETURN json_build_object(
    'success', true,
    'banned', false,
    'device_id', v_install,
    'android_id', v_android,
    'session_replaced', (v_prev_device IS NOT NULL AND v_prev_device IS DISTINCT FROM v_install),
    'previous_device_id', v_prev_device,
    'sessions_revoked', v_kicked
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.register_my_device(text, text, text) TO authenticated;

COMMENT ON FUNCTION public.register_my_device(text, text, text) IS
  'Registers device fingerprints for ban checks and enforces single-device login by revoking older auth sessions when last_device_id changes.';
