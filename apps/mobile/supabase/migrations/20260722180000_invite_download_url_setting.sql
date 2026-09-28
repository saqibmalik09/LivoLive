-- Invite Friends share / download URL (editable in Admin → System Config).
INSERT INTO public.system_settings (key, value, description)
VALUES (
  'invite_download_url',
  'https://sklive-landing.vercel.app',
  'Invite Friends share link. Shown when users tap Invite / share their invitation code. No trailing slash.'
)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = timezone('utc'::text, now());
