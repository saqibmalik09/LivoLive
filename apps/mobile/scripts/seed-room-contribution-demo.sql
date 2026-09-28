-- Demo seed: mock users, agency, host room, gift_logs for room contribution testing.
-- Run in Supabase SQL Editor (service role). Idempotent — safe to re-run.
--
-- Demo room id: b3000001-0001-4001-8001-000000000001
-- Login (optional): demo-host@sklive.test / Demo1234!

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Auth users (demo host + 6 contributors + agency owner)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_instance uuid := '00000000-0000-0000-0000-000000000000';
  rec record;
BEGIN
  FOR rec IN
    SELECT *
    FROM (VALUES
      ('b1000001-0001-4001-8001-000000000001'::uuid, 'demo-host@sklive.test', 'DemoHost_Rajput'),
      ('b1000001-0001-4001-8001-000000000002'::uuid, 'demo-agency@sklive.test', 'Agency_Boss'),
      ('b1000001-0001-4001-8001-000000000011'::uuid, 'demo-u1@sklive.test', 'A L i Rajput'),
      ('b1000001-0001-4001-8001-000000000012'::uuid, 'demo-u2@sklive.test', 'Hafsa Ch'),
      ('b1000001-0001-4001-8001-000000000013'::uuid, 'demo-u3@sklive.test', 'Barby'),
      ('b1000001-0001-4001-8001-000000000014'::uuid, 'demo-u4@sklive.test', 'Cute Peri'),
      ('b1000001-0001-4001-8001-000000000015'::uuid, 'demo-u5@sklive.test', 'Balla'),
      ('b1000001-0001-4001-8001-000000000016'::uuid, 'demo-u6@sklive.test', 'Sara Khan')
    ) AS t(id, email, username)
  LOOP
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    )
    VALUES (
      rec.id,
      v_instance,
      'authenticated',
      'authenticated',
      rec.email,
      crypt('Demo1234!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', rec.username),
      now(),
      now()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    )
    VALUES (
      rec.id,
      rec.id,
      jsonb_build_object('sub', rec.id::text, 'email', rec.email),
      'email',
      rec.id::text,
      now(),
      now(),
      now()
    )
    ON CONFLICT (provider, provider_id) DO NOTHING;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2. public.users (avatars + charm / wealth levels)
-- ---------------------------------------------------------------------------

INSERT INTO public.users (
  id, username, avatar_url, short_id, coins, diamonds,
  user_level, charm_level, charm_value, wealth_level, wealth_value,
  country_code, gender, is_banned, created_at, updated_at
)
VALUES
  ('b1000001-0001-4001-8001-000000000001', 'DemoHost_Rajput', 'https://i.pravatar.cc/200?img=11', 900001, 500000, 0, 10, 15, 25000, 10, 500000, 'PK', 'male', false, now(), now()),
  ('b1000001-0001-4001-8001-000000000002', 'Agency_Boss', 'https://i.pravatar.cc/200?img=33', 900002, 100000, 0, 8, 10, 10000, 8, 80000, 'PK', 'male', false, now(), now()),
  ('b1000001-0001-4001-8001-000000000011', 'A L i Rajput', 'https://i.pravatar.cc/200?img=11', 900011, 5000000, 0, 10, 15, 25000, 10, 500000, 'PK', 'male', false, now(), now()),
  ('b1000001-0001-4001-8001-000000000012', 'Hafsa Ch', 'https://i.pravatar.cc/200?img=5', 900012, 200000, 0, 6, 6, 6000, 4, 4000, 'PK', 'female', false, now(), now()),
  ('b1000001-0001-4001-8001-000000000013', 'Barby', 'https://i.pravatar.cc/200?img=9', 900013, 50000, 0, 5, 5, 5000, 3, 3000, 'PK', 'female', false, now(), now()),
  ('b1000001-0001-4001-8001-000000000014', 'Cute Peri', 'https://i.pravatar.cc/200?img=16', 900014, 40000, 0, 4, 4, 4000, 2, 2000, 'PK', 'female', false, now(), now()),
  ('b1000001-0001-4001-8001-000000000015', 'Balla', 'https://i.pravatar.cc/200?img=12', 900015, 30000, 0, 3, 3, 3000, 2, 1500, 'PK', 'male', false, now(), now()),
  ('b1000001-0001-4001-8001-000000000016', 'Sara Khan', 'https://i.pravatar.cc/200?img=20', 900016, 20000, 0, 2, 2, 2000, 1, 1000, 'PK', 'female', false, now(), now())
ON CONFLICT (id) DO UPDATE SET
  username = EXCLUDED.username,
  avatar_url = EXCLUDED.avatar_url,
  user_level = EXCLUDED.user_level,
  charm_level = EXCLUDED.charm_level,
  wealth_level = EXCLUDED.wealth_level,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 3. Agency + host membership
-- ---------------------------------------------------------------------------

INSERT INTO public.agencies (id, owner_id, name, agency_code, is_active, created_at)
VALUES (
  'b2000001-0001-4001-8001-000000000001',
  'b1000001-0001-4001-8001-000000000002',
  'SK Stars Agency',
  'SKSTAR',
  true,
  now()
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  agency_code = EXCLUDED.agency_code,
  is_active = true;

INSERT INTO public.agency_members (agency_id, user_id, joined_at)
VALUES (
  'b2000001-0001-4001-8001-000000000001',
  'b1000001-0001-4001-8001-000000000001',
  now()
)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Demo room (agency host)
-- ---------------------------------------------------------------------------

INSERT INTO public.rooms (
  id, host_id, title, image_url, background_url, room_topic,
  is_active, is_private, country_code, mic_count, created_at
)
VALUES (
  'b3000001-0001-4001-8001-000000000001',
  'b1000001-0001-4001-8001-000000000001',
  'VIP Lounge Room',
  'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400',
  'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800',
  'chat',
  true,
  false,
  'PK',
  8,
  now()
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  image_url = EXCLUDED.image_url,
  is_active = true;

INSERT INTO public.room_stats (room_id, total_exp, hotness_score, updated_at)
VALUES ('b3000001-0001-4001-8001-000000000001', 2030000, 2030000, now())
ON CONFLICT (room_id) DO UPDATE SET
  total_exp = EXCLUDED.total_exp,
  hotness_score = EXCLUDED.hotness_score,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 5. Gift logs → room contribution rankings (today)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_room uuid := 'b3000001-0001-4001-8001-000000000001';
  v_host uuid := 'b1000001-0001-4001-8001-000000000001';
  v_gift uuid;
BEGIN
  SELECT id INTO v_gift
  FROM public.shop_items
  WHERE is_gift = true AND is_active = true
  ORDER BY price_coins ASC
  LIMIT 1;

  IF v_gift IS NULL THEN
    SELECT id INTO v_gift FROM public.gifts WHERE is_active = true LIMIT 1;
  END IF;

  IF v_gift IS NULL THEN
    RAISE NOTICE 'No gift item found — load catalog_data.sql first.';
    RETURN;
  END IF;

  DELETE FROM public.gift_logs
  WHERE room_id = v_room
    AND sender_id IN (
      'b1000001-0001-4001-8001-000000000011',
      'b1000001-0001-4001-8001-000000000012',
      'b1000001-0001-4001-8001-000000000013',
      'b1000001-0001-4001-8001-000000000014',
      'b1000001-0001-4001-8001-000000000015',
      'b1000001-0001-4001-8001-000000000016'
    );

  INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount, created_at)
  VALUES
    ('b1000001-0001-4001-8001-000000000011', v_host, v_gift, v_room, 1900000, now()),
    ('b1000001-0001-4001-8001-000000000012', v_host, v_gift, v_room, 126000, now()),
    ('b1000001-0001-4001-8001-000000000013', v_host, v_gift, v_room, 1200, now()),
    ('b1000001-0001-4001-8001-000000000014', v_host, v_gift, v_room, 1100, now()),
    ('b1000001-0001-4001-8001-000000000015', v_host, v_gift, v_room, 980, now()),
    ('b1000001-0001-4001-8001-000000000016', v_host, v_gift, v_room, 750, now());
END $$;
