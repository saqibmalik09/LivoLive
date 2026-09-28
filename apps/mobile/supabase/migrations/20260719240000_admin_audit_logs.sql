-- Platform / Super Admin activity audit trail.

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  source text NOT NULL DEFAULT 'sklive-admin',
  actor_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  actor_staff_id uuid,
  actor_label text,
  action text NOT NULL,
  target_type text,
  target_id text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  success boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS admin_audit_logs_created_at_idx
  ON public.admin_audit_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS admin_audit_logs_action_idx
  ON public.admin_audit_logs (action);

CREATE INDEX IF NOT EXISTS admin_audit_logs_actor_user_idx
  ON public.admin_audit_logs (actor_user_id);

CREATE INDEX IF NOT EXISTS admin_audit_logs_target_idx
  ON public.admin_audit_logs (target_type, target_id);

COMMENT ON TABLE public.admin_audit_logs IS
  'Audit trail for platform admin and staff-portal (Super Admin) actions.';

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.admin_audit_logs TO service_role;
GRANT SELECT ON public.admin_audit_logs TO authenticated;

DROP POLICY IF EXISTS "Staff can read admin audit logs" ON public.admin_audit_logs;
CREATE POLICY "Staff can read admin audit logs"
  ON public.admin_audit_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.business_staff bs
      WHERE bs.user_id = auth.uid()
        AND bs.is_active = true
    )
  );

-- Authenticated staff portal writes (actor taken from auth.uid()).
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

  SELECT bs.id INTO v_staff_id
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

  SELECT COALESCE(u.username, 'Staff') INTO v_label
  FROM public.users u
  WHERE u.id = v_uid;

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

GRANT EXECUTE ON FUNCTION public.log_admin_audit(
  text, text, text, text, jsonb, boolean, text
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.list_admin_audit_logs(
  p_limit int DEFAULT 100,
  p_action text DEFAULT NULL,
  p_source text DEFAULT NULL
)
RETURNS SETOF public.admin_audit_logs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    IF auth.uid() IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.business_staff bs
      WHERE bs.user_id = auth.uid() AND bs.is_active = true
    ) THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;
  END IF;

  RETURN QUERY
  SELECT l.*
  FROM public.admin_audit_logs l
  WHERE (p_action IS NULL OR btrim(p_action) = '' OR l.action = btrim(p_action))
    AND (p_source IS NULL OR btrim(p_source) = '' OR l.source = btrim(p_source))
  ORDER BY l.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$function$;

GRANT EXECUTE ON FUNCTION public.list_admin_audit_logs(int, text, text)
  TO authenticated, service_role;
