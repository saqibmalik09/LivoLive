-- Enable realtime for global win announcements (app-wide SVGA broadcast)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'global_win_announcements'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.global_win_announcements;
  END IF;
END $$;
