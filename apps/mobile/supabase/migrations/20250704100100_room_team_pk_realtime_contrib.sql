DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'room_pk_gift_contributions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.room_pk_gift_contributions;
  END IF;
END $$;
