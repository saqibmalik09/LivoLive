-- Mock agency rankings for Gift Center Agency tab (daily / weekly / monthly).
-- Run in Supabase SQL Editor (service role). Idempotent — safe to re-run.
--
-- Demo agency ids: c3000001-0001-4001-8001-000000000001 .. 000000000030

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Demo agency owners (30 users)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_instance uuid := '00000000-0000-0000-0000-000000000000';
  i int;
  v_user_id uuid;
  v_email text;
  v_username text;
BEGIN
  FOR i IN 1..30 LOOP
    v_user_id := ('c3000001-0001-4001-8001-' || lpad(i::text, 12, '0'))::uuid;
    v_email := 'agency-rank-' || i || '@sklive.demo';
    v_username := 'AgencyBoss_' || i;

    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    )
    VALUES (
      v_user_id,
      v_instance,
      'authenticated',
      'authenticated',
      v_email,
      crypt('Demo1234!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', v_username),
      now(),
      now()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    )
    VALUES (
      v_user_id,
      v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', v_email),
      'email',
      v_user_id::text,
      now(),
      now(),
      now()
    )
    ON CONFLICT (provider, provider_id) DO NOTHING;

    INSERT INTO public.users (
      id, username, avatar_url, short_id, coins, diamonds,
      user_level, charm_level, charm_value, wealth_level, wealth_value,
      country_code, gender, is_banned, created_at, updated_at
    )
    VALUES (
      v_user_id,
      v_username,
      'https://i.pravatar.cc/200?img=' || ((i % 70) + 1),
      910000 + i,
      100000,
      0,
      5 + (i % 10),
      5 + (i % 8),
      5000 * i,
      5 + (i % 10),
      8000 * i,
      'PK',
      CASE WHEN i % 2 = 0 THEN 'female' ELSE 'male' END,
      false,
      now(),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      username = EXCLUDED.username,
      avatar_url = EXCLUDED.avatar_url,
      updated_at = now();
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Demo agencies (30)
-- ---------------------------------------------------------------------------

INSERT INTO public.agencies (id, owner_id, name, agency_code, is_active, created_at)
SELECT
  ('c3100001-0001-4001-8001-' || lpad(gs::text, 12, '0'))::uuid,
  ('c3000001-0001-4001-8001-' || lpad(gs::text, 12, '0'))::uuid,
  CASE gs
    WHEN 1 THEN 'SK Stars Agency'
    WHEN 2 THEN 'Royal Lions'
    WHEN 3 THEN 'Golden Phoenix'
    ELSE 'Elite Agency ' || gs
  END,
  lpad((100000 + gs)::text, 6, '0'),
  true,
  now()
FROM generate_series(1, 30) AS gs
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  agency_code = EXCLUDED.agency_code,
  is_active = true;

-- ---------------------------------------------------------------------------
-- 3. Demo earning logs (powers refresh_agency_rankings)
-- ---------------------------------------------------------------------------

DELETE FROM public.earning_logs
WHERE agency_owner_id::text LIKE 'c3000001-0001-4001-8001-%';

INSERT INTO public.earning_logs (
  host_id,
  host_amount,
  agency_owner_id,
  agency_amount,
  admin_amount,
  total_gift_value,
  created_at
)
SELECT
  ('c3000001-0001-4001-8001-' || lpad(gs::text, 12, '0'))::uuid,
  0,
  ('c3000001-0001-4001-8001-' || lpad(gs::text, 12, '0'))::uuid,
  GREATEST(1000, (31 - gs) * 520000)::int,
  0,
  GREATEST(1000, (31 - gs) * 520000)::int,
  now()
FROM generate_series(1, 30) AS gs;

-- ---------------------------------------------------------------------------
-- 4. Refresh agency rankings from earning logs
-- ---------------------------------------------------------------------------

SELECT public.refresh_agency_rankings();

SELECT ranking_type, COUNT(*) AS rows
FROM public.agency_rankings
GROUP BY ranking_type
ORDER BY ranking_type;
