-- C1: Private KYC bucket. C2/M11: lock down system_settings secrets. M10: no anon full users dump.

-- ========== C1: real_name_kyc private ==========
UPDATE storage.buckets
SET public = false
WHERE id = 'real_name_kyc';

DROP POLICY IF EXISTS "Public read real_name_kyc" ON storage.objects;

DROP POLICY IF EXISTS "Owner read real_name_kyc" ON storage.objects;
CREATE POLICY "Owner read real_name_kyc"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'real_name_kyc'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Keep existing owner upload/update policies (folder = auth.uid).
-- service_role bypasses RLS for admin signed URLs.

-- ========== C2/M11: system_settings ==========
ALTER TABLE IF EXISTS public.system_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public Read Access" ON public.system_settings;
DROP POLICY IF EXISTS "Authenticated read non-secret system_settings" ON public.system_settings;

-- Clients may read non-secret keys only (never zego_app_sign / server secrets).
CREATE POLICY "Authenticated read non-secret system_settings"
  ON public.system_settings
  FOR SELECT
  TO authenticated
  USING (
    key NOT IN (
      'zego_app_sign',
      'zego_server_secret',
      'zego_server_secret_key',
      'supabase_service_role_key',
      'jwt_secret'
    )
  );

-- Remove AppSign from readable settings store (rotate in Zego console after token deploy).
UPDATE public.system_settings
SET value = '',
    description = COALESCE(description, '') || ' [purged — use edge zego-token + ServerSecret]'
WHERE key = 'zego_app_sign';

-- ========== M10: users SELECT ==========
DROP POLICY IF EXISTS "Public read users" ON public.users;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.users;
DROP POLICY IF EXISTS "Authenticated read users" ON public.users;

CREATE POLICY "Authenticated read users"
  ON public.users
  FOR SELECT
  TO authenticated
  USING (true);

-- Safe public profile surface (no economy / PII / device / tokens).
CREATE OR REPLACE VIEW public.public_user_profiles
WITH (security_invoker = false)
AS
SELECT
  u.id,
  u.username,
  u.avatar_url,
  u.short_id,
  u.vip_level,
  u.wealth_level,
  u.charm_level,
  u.country_code,
  u.gender,
  u.bio
FROM public.users u;

REVOKE ALL ON public.public_user_profiles FROM PUBLIC;
GRANT SELECT ON public.public_user_profiles TO anon, authenticated;

COMMENT ON VIEW public.public_user_profiles IS
  'Safe profile fields for public/card display. Full users row requires authenticated.';
