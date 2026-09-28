-- Ensure pg_cron refreshes ranking tables every 2 minutes on Zuvo.
-- Rankings had gone stale (~Aug 21) because pg_cron was not installed / not scheduled.

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $outer$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname IN ('refresh-rankings', 'refresh_rankings');
EXCEPTION
  WHEN undefined_table THEN NULL;
  WHEN others THEN NULL;
END;
$outer$;

DO $outer$
BEGIN
  PERFORM cron.schedule(
    'refresh-rankings',
    '*/2 * * * *',
    $cron$
      SELECT public.refresh_gift_rankings();
      SELECT public.refresh_charm_rankings();
      SELECT public.refresh_room_rankings();
      SELECT public.refresh_agency_rankings();
      SELECT public.refresh_game_rankings();
    $cron$
  );
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END;
$outer$;
