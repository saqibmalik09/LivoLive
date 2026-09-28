-- Richer Super Admin actor labels on audit rows (username · role · staff_code).

CREATE OR REPLACE FUNCTION public.log_admin_audit(
  p_action text,
  p_target_type text DEFAULT NULL,
  p_target_id text DEFAULT NULL,
  p_summary text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_success boolean DEFAULT true,
  p_source text DEFAULT 'sklive-super-admin'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff_id uuid;
  v_staff_role text;
  v_staff_code text;
  v_username text;
  v_label text;
  v_id uuid;
BEGIN
  IF p_action IS NULL OR btrim(p_action) = '' THEN
    RAISE EXCEPTION 'action required';
  END IF;

  IF auth.role() = 'service_role' THEN
    INSERT INTO public.admin_audit_logs (
      source, actor_user_id, actor_staff_id, actor_label,
      action, target_type, target_id, summary, metadata, success
    ) VALUES (
      COALESCE(NULLIF(btrim(p_source), ''), 'sklive-admin'),
      NULL, NULL, 'Platform Admin',
      btrim(p_action),
      NULLIF(btrim(p_target_type), ''),
      NULLIF(btrim(p_target_id), ''),
      NULLIF(btrim(p_summary), ''),
      COALESCE(p_metadata, '{}'::jsonb),
      COALESCE(p_success, true)
    )
    RETURNING id INTO v_id;
    RETURN v_id;
  END IF;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT bs.id, bs.role, bs.staff_code
  INTO v_staff_id, v_staff_role, v_staff_code
  FROM public.business_staff bs
  WHERE bs.user_id = v_uid
    AND bs.is_active = true
  ORDER BY
    CASE bs.role
      WHEN 'super_bd' THEN 1
      WHEN 'county_admin' THEN 2
      WHEN 'bd_admin' THEN 2
      WHEN 'bd' THEN 3
      ELSE 9
    END
  LIMIT 1;

  IF v_staff_id IS NULL THEN
    RAISE EXCEPTION 'Active staff required';
  END IF;

  SELECT COALESCE(u.username, 'Staff') INTO v_username
  FROM public.users u
  WHERE u.id = v_uid;

  v_label := v_username
    || ' · '
    || CASE COALESCE(v_staff_role, '')
         WHEN 'super_bd' THEN 'Super Admin'
         WHEN 'county_admin' THEN 'County Admin'
         WHEN 'bd_admin' THEN 'County Admin'
         WHEN 'bd' THEN 'BD'
         WHEN 'assistant' THEN 'Assistant'
         WHEN 'customer_service' THEN 'Customer Service'
         ELSE COALESCE(v_staff_role, 'Staff')
       END
    || CASE WHEN v_staff_code IS NOT NULL AND v_staff_code <> ''
            THEN ' · ' || v_staff_code
            ELSE ''
       END;

  INSERT INTO public.admin_audit_logs (
    source, actor_user_id, actor_staff_id, actor_label,
    action, target_type, target_id, summary, metadata, success
  ) VALUES (
    COALESCE(NULLIF(btrim(p_source), ''), 'sklive-super-admin'),
    v_uid,
    v_staff_id,
    v_label,
    btrim(p_action),
    NULLIF(btrim(p_target_type), ''),
    NULLIF(btrim(p_target_id), ''),
    NULLIF(btrim(p_summary), ''),
    COALESCE(p_metadata, '{}'::jsonb),
    COALESCE(p_success, true)
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
