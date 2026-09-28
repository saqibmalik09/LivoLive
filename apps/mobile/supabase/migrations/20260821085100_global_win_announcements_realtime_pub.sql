-- Ensure global win banners reach clients via Realtime on Zuvo / fresh envs.
-- Without this, proxy/edge inserts succeed but the app never receives them.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'global_win_announcements'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.global_win_announcements;
  END IF;
END $$;

ALTER TABLE public.global_win_announcements REPLICA IDENTITY FULL;
