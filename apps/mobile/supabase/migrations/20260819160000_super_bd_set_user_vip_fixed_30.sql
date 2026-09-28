-- Super BD: set VIP level for any user (mobile + portal)
-- VIP duration: fixed 30 days by default
-- Behavior: extend-if-active when replaceExpiry=false

CREATE OR REPLACE FUNCTION public.super_bd_set_user_vip(
  p_target_user_id uuid,
  p_vip_level int,
  p_days int DEFAULT 30,
  p_replace_expiry boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  -- Ensures the caller is a super_bd; SECURITY DEFINER protects the privilege escalation.
  -- We don't need the returned user id, but we must call it for authorization.
  v_level int := COALESCE(p_vip_level, 0);
  v_days int := COALESCE(p_days, 30);
  v_now timestamptz := now();
  v_current_until timestamptz;
  v_new_until timestamptz;
BEGIN
  PERFORM public.assert_super_bd();
  IF p_target_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'target user required');
  END IF;

  -- Only allow VIP levels up to 4 as requested.
  IF v_level < 0 OR v_level > 4 THEN
    RETURN json_build_object('success', false, 'message', 'vip_level must be 0..4');
  END IF;

  IF v_days < 1 THEN
    v_days := 30;
  END IF;

  IF v_level = 0 THEN
    UPDATE public.users
    SET vip_level = 0,
        vip_until = NULL,
        updated_at = now()
    WHERE id = p_target_user_id;

    -- provision_user_assets() won't "insert" anything when vip_level=0,
    -- so expire existing VIP inventory rows immediately to stop visibility.
    UPDATE public.user_inventory
    SET expires_at = now(),
        source = 'vip_reward'
    WHERE user_id = p_target_user_id
      AND source = 'vip_reward'
      AND (expires_at IS NULL OR expires_at > now());

    PERFORM public.provision_user_assets(p_target_user_id);

    RETURN json_build_object(
      'success', true,
      'target_user_id', p_target_user_id,
      'vip_level', 0,
      'vip_until', NULL
    );
  END IF;

  SELECT vip_until
    INTO v_current_until
    FROM public.users
    WHERE id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'user not found');
  END IF;

  IF v_current_until IS NOT NULL
     AND v_current_until > v_now
     AND COALESCE(p_replace_expiry, false) = false THEN
    v_new_until := v_current_until + make_interval(days => v_days);
  ELSE
    v_new_until := v_now + make_interval(days => v_days);
  END IF;

  UPDATE public.users
  SET vip_level = v_level,
      vip_until = v_new_until,
      updated_at = now()
  WHERE id = p_target_user_id;

  -- Provision assets so app VIP UI immediately reflects.
  PERFORM public.provision_user_assets(p_target_user_id);

  RETURN json_build_object(
    'success', true,
    'target_user_id', p_target_user_id,
    'vip_level', v_level,
    'vip_until', v_new_until
  );
EXCEPTION
  WHEN others THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.super_bd_set_user_vip(uuid, int, int, boolean)
  TO authenticated;

