-- Game engine ownership: sklive-game-worker (Redis lock + advance_game_rounds).
-- Disable pg_cron tick to avoid double settlement / double coin credit.
--
-- Apply ONLY after the game-worker is deployed and healthy with REDIS_URL.
-- Until then, leave advance-game-rounds cron active so games keep ticking.
-- Helper: sklive-scripts/disable_game_cron.js

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
