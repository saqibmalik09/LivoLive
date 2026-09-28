-- Room public ID = host user short_id (same number for room + user).

ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS short_id bigint;

COMMENT ON COLUMN public.rooms.short_id IS
  'Public room ID — same as host users.short_id.';

-- Backfill existing rooms from host.
UPDATE public.rooms r
SET short_id = u.short_id
FROM public.users u
WHERE u.id = r.host_id
  AND (r.short_id IS DISTINCT FROM u.short_id);

-- Any room still missing short_id (orphan host): assign from sequence-like unique values.
DO $$
DECLARE
  r RECORD;
  v_next bigint;
BEGIN
  FOR r IN
    SELECT id FROM public.rooms WHERE short_id IS NULL
  LOOP
    LOOP
      v_next := (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::bigint % 900000000
                + (random() * 100000)::int;
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.rooms WHERE short_id = v_next
      ) AND NOT EXISTS (
        SELECT 1 FROM public.users WHERE short_id = v_next
      );
    END LOOP;
    UPDATE public.rooms SET short_id = v_next WHERE id = r.id;
  END LOOP;
END $$;

ALTER TABLE public.rooms
  ALTER COLUMN short_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rooms_short_id_key
  ON public.rooms (short_id);

-- On room create / host change: copy host short_id.
CREATE OR REPLACE FUNCTION public.rooms_set_short_id_from_host()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_sid bigint;
BEGIN
  IF NEW.host_id IS NULL THEN
    RAISE EXCEPTION 'Room host_id required';
  END IF;

  SELECT short_id INTO v_sid
  FROM public.users
  WHERE id = NEW.host_id;

  IF v_sid IS NULL THEN
    RAISE EXCEPTION 'Host user short_id not found';
  END IF;

  NEW.short_id := v_sid;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_rooms_set_short_id ON public.rooms;
CREATE TRIGGER trg_rooms_set_short_id
  BEFORE INSERT OR UPDATE OF host_id
  ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.rooms_set_short_id_from_host();

-- When user short_id changes, keep their room ID in sync.
CREATE OR REPLACE FUNCTION public.users_sync_room_short_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
BEGIN
  IF NEW.short_id IS DISTINCT FROM OLD.short_id THEN
    UPDATE public.rooms
    SET short_id = NEW.short_id
    WHERE host_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_users_sync_room_short_id ON public.users;
CREATE TRIGGER trg_users_sync_room_short_id
  AFTER UPDATE OF short_id
  ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.users_sync_room_short_id();

-- Keep admin special-id RPC in sync (trigger also covers it).
CREATE OR REPLACE FUNCTION public.admin_set_user_special_id(
  p_user_id uuid,
  p_level smallint DEFAULT NULL,
  p_short_id bigint DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'user_id required');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  IF p_level IS NOT NULL AND p_level <> 0 THEN
    IF p_level < 1 OR p_level > 9 THEN
      RETURN json_build_object('success', false, 'message', 'Level must be 1-9 or 0 to clear');
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.special_id_styles WHERE level = p_level AND is_active
    ) THEN
      RETURN json_build_object('success', false, 'message', 'Style level not found');
    END IF;
  END IF;

  IF p_short_id IS NOT NULL THEN
    IF p_short_id < 1 THEN
      RETURN json_build_object('success', false, 'message', 'Invalid short_id');
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.users
      WHERE short_id = p_short_id AND id IS DISTINCT FROM p_user_id
    ) THEN
      RETURN json_build_object('success', false, 'message', 'That ID is already taken');
    END IF;
    -- Room uniqueness is same as user uniqueness (1 room per host).
    IF EXISTS (
      SELECT 1 FROM public.rooms r
      WHERE r.short_id = p_short_id
        AND r.host_id IS DISTINCT FROM p_user_id
    ) THEN
      RETURN json_build_object('success', false, 'message', 'That ID is already used by a room');
    END IF;
  END IF;

  UPDATE public.users
  SET
    special_id_level = CASE
      WHEN p_level IS NULL THEN special_id_level
      WHEN p_level = 0 THEN NULL
      ELSE p_level
    END,
    short_id = COALESCE(p_short_id, short_id),
    updated_at = now()
  WHERE id = p_user_id;

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Special ID updated',
    'short_id', v_user.short_id,
    'special_id_level', v_user.special_id_level
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_special_id(uuid, smallint, bigint) TO service_role;
