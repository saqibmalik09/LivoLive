CREATE OR REPLACE FUNCTION public.weekly_room_reward_week_bounds(p_at timestamp with time zone DEFAULT now())
 RETURNS TABLE(week_start timestamp with time zone, week_end timestamp with time zone, period_key text, claim_deadline timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  WITH cfg AS (
    SELECT timestamptz '2026-10-31 19:00:00+00' AS cutover
  ),
  legacy AS (
    SELECT date_trunc('day', p_at AT TIME ZONE 'UTC+3')
             - ((EXTRACT(DOW FROM (p_at AT TIME ZONE 'UTC+3'))::integer) * interval '1 day') AS week_start_local
  ),
  daily AS (
    SELECT date_trunc('day', p_at AT TIME ZONE 'Asia/Karachi') AS day_local
  )
  SELECT
    (l.week_start_local AT TIME ZONE 'UTC+3'),
    LEAST((l.week_start_local + interval '7 days') AT TIME ZONE 'UTC+3', c.cutover),
    to_char(l.week_start_local, 'YYYY-MM-DD'),
    CASE
      WHEN (l.week_start_local + interval '7 days') AT TIME ZONE 'UTC+3' > c.cutover
        THEN c.cutover + interval '1 day'
      ELSE (l.week_start_local + interval '13 days') AT TIME ZONE 'UTC+3'
    END
  FROM cfg c, legacy l
  WHERE p_at < c.cutover
  UNION ALL
  SELECT
    (d.day_local AT TIME ZONE 'Asia/Karachi'),
    ((d.day_local + interval '1 day') AT TIME ZONE 'Asia/Karachi'),
    to_char(d.day_local, 'YYYY-MM-DD'),
    ((d.day_local + interval '2 days') AT TIME ZONE 'Asia/Karachi')
  FROM cfg c, daily d
  WHERE p_at >= c.cutover;
$function$;

UPDATE public.weekly_room_reward_rules
SET rules = jsonb_set(
              jsonb_set(rules, '{0}', to_jsonb('Cycle Period: Every day from 00:00 to 24:00 (Pakistan time).'::text)),
              '{4}', to_jsonb('Rewards must be claimed within 24 hours (during the next day); expired rewards will disappear. Please claim your rewards in time.'::text)),
    updated_at = now()
WHERE id = 1
  AND rules ->> 0 LIKE 'Cycle Period: Every Sunday%'
  AND rules ->> 4 LIKE 'Rewards must be claimed within 6 days%';
