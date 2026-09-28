-- Restore missing on_auth_user_created trigger.
-- Since ~2026-08-20 ~21:32 UTC, auth.users inserts had no public.users row
-- (only zuvo_quota_auth_users remained on auth.users).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_base text;
  v_username text;
  v_avatar text;
  v_phone text;
  v_i int := 0;
BEGIN
  v_base := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data->>'username'), ''),
    NULLIF(btrim(NEW.raw_user_meta_data->>'name'), ''),
    NULLIF(btrim(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''),
    'User_' || substr(replace(NEW.id::text, '-', ''), 1, 8)
  );
  v_base := left(regexp_replace(v_base, '\s+', ' ', 'g'), 40);
  v_username := v_base;

  WHILE EXISTS (SELECT 1 FROM public.users WHERE username = v_username) LOOP
    v_i := v_i + 1;
    v_username := left(v_base, 32) || '_' || substr(replace(NEW.id::text, '-', ''), 1, 4) || v_i::text;
    IF v_i > 20 THEN
      v_username := 'User_' || substr(replace(NEW.id::text, '-', ''), 1, 12);
      EXIT;
    END IF;
  END LOOP;

  v_avatar := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'avatar_url', ''),
    NULLIF(NEW.raw_user_meta_data->>'picture', ''),
    NULLIF(NEW.raw_user_meta_data->>'avatar', '')
  );

  v_phone := NULLIF(NEW.phone, '');
  IF v_phone IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.users WHERE phone = v_phone AND id IS DISTINCT FROM NEW.id
  ) THEN
    v_phone := NULL;
  END IF;

  INSERT INTO public.users (id, username, avatar_url, phone)
  VALUES (NEW.id, v_username, v_avatar, v_phone)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user failed for %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Backfill auth users missing public.users (Aug 20+ orphans).
DO $$
DECLARE
  r record;
  v_base text;
  v_username text;
  v_avatar text;
  v_phone text;
  v_i int;
  v_ok int := 0;
  v_fail int := 0;
BEGIN
  FOR r IN
    SELECT au.id, au.email, au.phone, au.raw_user_meta_data
    FROM auth.users au
    LEFT JOIN public.users pu ON pu.id = au.id
    WHERE pu.id IS NULL
    ORDER BY au.created_at
  LOOP
    BEGIN
      v_i := 0;
      v_base := COALESCE(
        NULLIF(btrim(r.raw_user_meta_data->>'username'), ''),
        NULLIF(btrim(r.raw_user_meta_data->>'name'), ''),
        NULLIF(btrim(r.raw_user_meta_data->>'full_name'), ''),
        NULLIF(split_part(COALESCE(r.email, ''), '@', 1), ''),
        'User_' || substr(replace(r.id::text, '-', ''), 1, 8)
      );
      v_base := left(regexp_replace(v_base, '\s+', ' ', 'g'), 40);
      v_username := v_base;

      WHILE EXISTS (SELECT 1 FROM public.users WHERE username = v_username) LOOP
        v_i := v_i + 1;
        v_username := left(v_base, 32) || '_' || substr(replace(r.id::text, '-', ''), 1, 4) || v_i::text;
        IF v_i > 20 THEN
          v_username := 'User_' || substr(replace(r.id::text, '-', ''), 1, 12);
          EXIT;
        END IF;
      END LOOP;

      v_avatar := COALESCE(
        NULLIF(r.raw_user_meta_data->>'avatar_url', ''),
        NULLIF(r.raw_user_meta_data->>'picture', ''),
        NULLIF(r.raw_user_meta_data->>'avatar', '')
      );

      v_phone := NULLIF(r.phone, '');
      IF v_phone IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.users WHERE phone = v_phone AND id IS DISTINCT FROM r.id
      ) THEN
        v_phone := NULL;
      END IF;

      INSERT INTO public.users (id, username, avatar_url, phone)
      VALUES (r.id, v_username, v_avatar, v_phone)
      ON CONFLICT (id) DO NOTHING;

      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'backfill user % failed: %', r.id, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE 'handle_new_user backfill ok=% fail=%', v_ok, v_fail;
END $$;
