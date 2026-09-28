-- Auto-advance game rounds every 5 seconds (betting -> spinning -> next round).
-- Without this, games freeze at 0s when betting_ends_at passes.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

DO $$
DECLARE
  v_job_id bigint;
BEGIN
  FOR v_job_id IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'advance-game-rounds'
  LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;
END $$;

SELECT cron.schedule(
  'advance-game-rounds',
  '5 seconds',
  $$SELECT public.advance_game_rounds();$$
);

-- Realtime so web games get round status updates.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'game_rounds'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.game_rounds;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'game_bets'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.game_bets;
  END IF;
END $$;
