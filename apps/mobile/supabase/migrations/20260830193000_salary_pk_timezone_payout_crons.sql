-- Salary periods stay A (1–15) / B (16–month end).
-- Policy clock → Pakistan (UTC+5). Exactly one agency + one BD payout cron.

UPDATE public.bd_center_settings
SET
  timezone = 'UTC+5',
  updated_at = now()
WHERE id = 1;

CREATE OR REPLACE FUNCTION public.policy_local_now(p_ts timestamptz DEFAULT now())
RETURNS timestamp
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_tz text := 'UTC+5';
  v_offset interval := interval '5 hours';
BEGIN
  SELECT COALESCE(timezone, 'UTC+5') INTO v_tz FROM public.bd_center_settings WHERE id = 1;
  IF v_tz ~ '^[Uu][Tt][Cc]([+-]\d{1,2})$' THEN
    v_offset := (substring(v_tz from '[+-]\d{1,2}') || ' hours')::interval;
  ELSIF v_tz ~ '^[+-]\d{1,2}$' THEN
    v_offset := (v_tz || ' hours')::interval;
  END IF;
  RETURN (p_ts AT TIME ZONE 'UTC') + v_offset;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_period_id_for_date(p_date date DEFAULT current_date)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_local_today date := public.policy_local_now(now())::date;
  v_tz text := 'UTC+5';
  v_offset interval := interval '5 hours';
BEGIN
  IF p_date = v_local_today OR p_date = CURRENT_DATE THEN
    RETURN public.get_period_id_for_ts(now());
  END IF;

  SELECT COALESCE(timezone, 'UTC+5') INTO v_tz FROM public.bd_center_settings WHERE id = 1;
  IF v_tz ~ '^[Uu][Tt][Cc]([+-]\d{1,2})$' THEN
    v_offset := (substring(v_tz from '[+-]\d{1,2}') || ' hours')::interval;
  ELSIF v_tz ~ '^[+-]\d{1,2}$' THEN
    v_offset := (v_tz || ' hours')::interval;
  END IF;

  -- Historical calendar day at local noon → UTC
  RETURN public.get_period_id_for_ts(
    ((p_date::text || ' 12:00:00')::timestamp - v_offset) AT TIME ZONE 'UTC'
  );
END;
$function$;

-- Period gate unchanged: day 1–15 = A, day 16+ = B (now on PK clock)
-- Agency cron: day 1 pays prev-B, day 16 pays A
-- BD cron: day 15 pays previous calendar month

DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname IN (
      'agency-payout-period-a',
      'agency-payout-period-b',
      'agency-payout-daily-check',
      'bd-monthly-payout-15th'
    )
       OR lower(command) LIKE '%run_scheduled_agency_period_payouts%'
       OR lower(command) LIKE '%run_scheduled_bd_monthly_payout%'
       OR lower(command) LIKE '%execute_agency_period_payout%'
       OR lower(command) LIKE '%execute_bd_monthly_payout%';

    -- PK (UTC+5) 00:05 = 19:05 UTC previous calendar day
    PERFORM cron.schedule(
      'agency-payout-daily-check',
      '5 19 * * *',
      'SELECT public.run_scheduled_agency_period_payouts();'
    );

    -- PK 15th 00:10 = 14th 19:10 UTC
    PERFORM cron.schedule(
      'bd-monthly-payout-15th',
      '10 19 14 * *',
      'SELECT public.run_scheduled_bd_monthly_payout();'
    );
  END IF;
END;
$cron$;
