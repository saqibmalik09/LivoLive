-- Filter audit logs by actor staff id (per Super Admin).

DROP FUNCTION IF EXISTS public.list_admin_audit_logs(int, text, text);

CREATE OR REPLACE FUNCTION public.list_admin_audit_logs(
  p_limit int DEFAULT 100,
  p_action text DEFAULT NULL,
  p_source text DEFAULT NULL,
  p_actor_staff_id uuid DEFAULT NULL
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
    AND (p_actor_staff_id IS NULL OR l.actor_staff_id = p_actor_staff_id)
  ORDER BY l.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$function$;

GRANT EXECUTE ON FUNCTION public.list_admin_audit_logs(int, text, text, uuid)
  TO authenticated, service_role;
