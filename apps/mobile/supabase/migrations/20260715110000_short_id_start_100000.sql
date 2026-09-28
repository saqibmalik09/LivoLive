-- New user short_id values start at 100000 (sequence historically ~1000).
-- Existing rows unchanged. Demo/bulk IDs in 880001–899999+ are ignored
-- when choosing the next value so real allocations begin at 100000.

DO $$
DECLARE
  v_seq text;
  v_next bigint;
BEGIN
  v_seq := pg_get_serial_sequence('public.users', 'short_id');

  IF v_seq IS NULL THEN
    IF to_regclass('public.user_short_id_seq') IS NOT NULL THEN
      v_seq := 'public.user_short_id_seq';
    ELSIF to_regclass('public.users_short_id_seq') IS NOT NULL THEN
      v_seq := 'public.users_short_id_seq';
    END IF;
  END IF;

  IF v_seq IS NULL THEN
    RAISE EXCEPTION 'No short_id sequence found on public.users';
  END IF;

  -- Prefer 100000 when free; otherwise first free id >= 100000
  -- below the demo/high block starting at 880000.
  SELECT COALESCE(
    (
      SELECT s.id
      FROM generate_series(100000::bigint, 879999::bigint) AS s(id)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.users u WHERE u.short_id = s.id
      )
      ORDER BY s.id
      LIMIT 1
    ),
    100000
  )
  INTO v_next;

  PERFORM setval(v_seq::regclass, v_next, false);

  RAISE NOTICE 'short_id next value set to % (seq=%)', v_next, v_seq;
END $$;
