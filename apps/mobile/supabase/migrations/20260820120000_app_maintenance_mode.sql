-- Global app kill-switch. Toggled from sklive-admin; read by the mobile app and
-- the realtime gateway.

-- Re-running the migration must never flip a live switch, so the value is only
-- seeded on first insert.
INSERT INTO public.system_settings (key, value, description)
VALUES (
  'app_maintenance_mode',
  'false',
  'Global maintenance kill-switch. "true" blocks the mobile app and rejects all realtime gateway connections.'
)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = timezone('utc'::text, now());

INSERT INTO public.system_settings (key, value, description)
VALUES (
  'app_maintenance_message',
  'We are performing scheduled maintenance. Please check back shortly.',
  'Message shown on the maintenance screen while app_maintenance_mode is "true".'
)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = timezone('utc'::text, now());

-- The gate must run before login, but system_settings is authenticated-only
-- (20260809120000_security_harden_kyc_settings_users.sql). Expose just these two
-- keys through a definer function instead of widening the table policy, mirroring
-- check_device_banned.
CREATE OR REPLACE FUNCTION public.get_app_maintenance()
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
  SELECT json_build_object(
    'enabled',
    COALESCE(
      (SELECT value FROM public.system_settings WHERE key = 'app_maintenance_mode'),
      'false'
    ) = 'true',
    'message',
    COALESCE(
      (SELECT value FROM public.system_settings WHERE key = 'app_maintenance_message'),
      ''
    )
  );
$function$;

REVOKE ALL ON FUNCTION public.get_app_maintenance() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_app_maintenance() TO anon, authenticated;

COMMENT ON FUNCTION public.get_app_maintenance() IS
  'Maintenance flag + message for the app gate. Readable signed out, unlike system_settings.';
