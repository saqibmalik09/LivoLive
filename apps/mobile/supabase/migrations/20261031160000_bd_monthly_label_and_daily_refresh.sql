CREATE OR REPLACE FUNCTION public.run_daily_bd_monthly_maintenance(p_now timestamptz DEFAULT now())
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_local timestamp := public.policy_local_now(p_now);
  v_period text := to_char(v_local, 'YYYY-MM') || '-M';
  v_label_created boolean;
  v_ok int := 0;
  v_err int := 0;
  r record;
BEGIN
  v_label_created := NOT EXISTS (SELECT 1 FROM public.salary_periods WHERE period_id = v_period);
  PERFORM public.ensure_salary_period(v_period);

  FOR r IN
    SELECT id FROM public.business_staff
    WHERE is_active AND public.normalize_staff_role(role) = 'bd'
  LOOP
    BEGIN
      PERFORM public.refresh_bd_monthly_stats(r.id, v_period);
      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN
      v_err := v_err + 1;
      RAISE WARNING 'bd monthly refresh failed for staff % (%): %', r.id, v_period, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'period', v_period,
    'label_created', v_label_created,
    'refreshed', v_ok,
    'failed', v_err
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.run_daily_bd_monthly_maintenance(timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.run_daily_bd_monthly_maintenance(timestamptz) TO service_role;

DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'bd-monthly-daily-maintenance';
    PERFORM cron.schedule(
      'bd-monthly-daily-maintenance',
      '20 19 * * *',
      'SELECT public.run_daily_bd_monthly_maintenance();'
    );
  END IF;
END;
$cron$;
