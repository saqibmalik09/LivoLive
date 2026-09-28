-- Super Admin ban/unban: any user (not only team subtree), and clear device bans on unban.

CREATE OR REPLACE FUNCTION public.super_bd_set_user_banned(
  p_target_user_id uuid,
  p_banned boolean,
  p_ban_reason text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff public.business_staff%ROWTYPE;
  v_note text := NULLIF(trim(COALESCE(p_ban_reason, '')), '');
  v_install text;
  v_android text;
  v_fcm text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_staff FROM public.business_staff
  WHERE user_id = v_uid AND is_active AND role = 'super_bd'
  LIMIT 1;

  IF v_staff.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Super Admin only');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_target_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  -- Do not allow banning yourself.
  IF p_target_user_id = v_uid THEN
    RETURN json_build_object('success', false, 'message', 'Cannot ban your own account');
  END IF;

  IF p_banned THEN
    UPDATE public.users
    SET
      is_banned = true,
      ban_reason = v_note,
      banned_at = now()
    WHERE id = p_target_user_id;
  ELSE
    UPDATE public.users
    SET
      is_banned = false,
      ban_reason = NULL,
      banned_at = NULL
    WHERE id = p_target_user_id;

    -- Clear device bans so the user can open the app again after unblock.
    SELECT
      NULLIF(trim(last_device_id), ''),
      NULLIF(trim(last_android_id), ''),
      NULLIF(trim(fcm_token), '')
    INTO v_install, v_android, v_fcm
    FROM public.users
    WHERE id = p_target_user_id;

    UPDATE public.banned_device_signals
    SET is_active = false
    WHERE is_active = true
      AND (
        last_user_id = p_target_user_id
        OR (v_install IS NOT NULL AND signal_type = 'install_id' AND signal_value = v_install)
        OR (v_android IS NOT NULL AND signal_type = 'android_id' AND signal_value = v_android)
        OR (v_fcm IS NOT NULL AND signal_type = 'fcm_token' AND signal_value = v_fcm)
      );

    IF to_regclass('public.banned_devices') IS NOT NULL THEN
      EXECUTE $q$
        UPDATE public.banned_devices
        SET is_active = false
        WHERE is_active = true
          AND (
            last_user_id = $1
            OR ($2 IS NOT NULL AND device_id = $2)
          )
      $q$
      USING p_target_user_id, v_install;
    END IF;
  END IF;

  RETURN json_build_object(
    'success', true,
    'user_id', p_target_user_id,
    'is_banned', p_banned,
    'ban_reason', CASE WHEN p_banned THEN v_note ELSE NULL END
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.super_bd_set_user_banned(uuid, boolean, text) TO authenticated;

-- Include ban status in staff user search (for moderation UI).
CREATE OR REPLACE FUNCTION public.search_users_for_staff_creation(p_query text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_trimmed text;
BEGIN
    PERFORM public.assert_super_bd();
    v_trimmed := trim(p_query);
    IF v_trimmed = '' THEN
        RETURN '[]'::json;
    END IF;

    IF v_trimmed ~ '^\d+$' THEN
        RETURN COALESCE((
            SELECT json_agg(row_to_json(t))
            FROM (
                SELECT
                  u.id,
                  u.username,
                  u.short_id,
                  u.avatar_url,
                  COALESCE(u.is_banned, false) AS is_banned,
                  u.ban_reason
                FROM public.users u
                WHERE u.short_id = v_trimmed::int
                LIMIT 8
            ) t
        ), '[]'::json);
    END IF;

    RETURN COALESCE((
        SELECT json_agg(row_to_json(t))
        FROM (
            SELECT
              u.id,
              u.username,
              u.short_id,
              u.avatar_url,
              COALESCE(u.is_banned, false) AS is_banned,
              u.ban_reason
            FROM public.users u
            WHERE u.username ILIKE '%' || v_trimmed || '%'
            ORDER BY u.username
            LIMIT 8
        ) t
    ), '[]'::json);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.search_users_for_staff_creation(text) TO authenticated;
