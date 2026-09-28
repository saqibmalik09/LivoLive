-- Restore supabase_realtime publication tables (was empty on Coolify).
-- Needed for wallet/coins live updates via users.stream and other postgres_changes.

DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'users',
    'rooms',
    'room_seats',
    'room_messages',
    'room_kicks',
    'room_invitations',
    'conversations',
    'chat_messages',
    'system_notifications',
    'topics',
    'tasks',
    'user_task_progress',
    'lucky_bags',
    'room_pk_sessions',
    'room_pk_gift_contributions',
    'global_win_announcements',
    'game_rounds',
    'game_bets',
    'teen_patti_rounds',
    'teen_patti_seats'
  ];
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;

  FOREACH t IN ARRAY tables LOOP
    IF to_regclass('public.' || t) IS NULL THEN
      RAISE NOTICE 'skip missing table: %', t;
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM pg_publication_rel pr
      JOIN pg_publication p ON p.oid = pr.prpubid
      JOIN pg_class c ON c.oid = pr.prrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE p.pubname = 'supabase_realtime'
        AND n.nspname = 'public'
        AND c.relname = t
    ) THEN
      CONTINUE;
    END IF;

    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    RAISE NOTICE 'added to supabase_realtime: %', t;
  END LOOP;
END $$;
