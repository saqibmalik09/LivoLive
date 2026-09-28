-- Optional cron: auto-draw ended rupee game campaigns (draw_mode = auto_random).

DO $outer$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;

    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname = 'rupee_game_auto_draw';

    PERFORM cron.schedule(
        'rupee_game_auto_draw',
        '0 * * * *',
        $$SELECT public.auto_draw_ended_campaigns();$$
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END;
$outer$;
