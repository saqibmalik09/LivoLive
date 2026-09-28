-- Restore 6-digit short_id allocation (start >= 100000).
-- Cause: user_short_id_seq had drifted back to ~1000 (4-digit), so new/backfilled
-- users after the handle_new_user outage got short_ids 1000–1460.
-- Remap those recent 4-digit rows into the organic 6-digit range, then setval.

DO $$
DECLARE
  v_seq text;
  v_next bigint;
  r record;
  v_new bigint;
  v_remapped int := 0;
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

  -- Next free id in organic band [100000, 880000)
  SELECT COALESCE(
    (
      SELECT s.id
      FROM generate_series(
        GREATEST(
          100000,
          (
            SELECT COALESCE(max(short_id) + 1, 100000)
            FROM public.users
            WHERE short_id >= 100000 AND short_id < 880000
          )
        )::bigint,
        879999::bigint
      ) AS s(id)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.users u WHERE u.short_id = s.id
      )
      ORDER BY s.id
      LIMIT 1
    ),
    100000
  )
  INTO v_next;

  -- Remap recent accidental 4-digit IDs (orphan backfill + new signups)
  FOR r IN
    SELECT id
    FROM public.users
    WHERE short_id >= 1000
      AND short_id < 10000
      AND created_at >= '2026-08-20T21:00:00Z'
    ORDER BY created_at, short_id
  LOOP
    -- find free id starting at v_next
    LOOP
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.users u WHERE u.short_id = v_next
      );
      v_next := v_next + 1;
      IF v_next >= 880000 THEN
        RAISE EXCEPTION 'short_id organic band exhausted';
      END IF;
    END LOOP;

    v_new := v_next;
    UPDATE public.users SET short_id = v_new WHERE id = r.id;
    v_next := v_next + 1;
    v_remapped := v_remapped + 1;
  END LOOP;

  -- Sequence: next nextval() returns v_next (is_called = false)
  PERFORM setval(v_seq::regclass, v_next, false);

  RAISE NOTICE 'remapped=% next_short_id=% seq=%', v_remapped, v_next, v_seq;
END $$;
