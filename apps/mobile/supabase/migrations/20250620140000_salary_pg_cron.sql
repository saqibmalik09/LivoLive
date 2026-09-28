-- Scheduled salary payout (requires pg_cron extension on Supabase)

DO $outer$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;

    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname IN ('salary-payout-15th', 'salary-payout-month-end');

    PERFORM cron.schedule(
        'salary-payout-15th',
        '30 0 15 * *',
        $$SELECT public.run_scheduled_salary_payout();$$
    );

    PERFORM cron.schedule(
        'salary-payout-month-end',
        '30 0 28-31 * *',
        $$SELECT public.run_scheduled_salary_payout();$$
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END;
$outer$;
