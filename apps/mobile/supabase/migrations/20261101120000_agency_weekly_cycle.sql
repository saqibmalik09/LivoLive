CREATE OR REPLACE FUNCTION public.agency_weekly_cutover_date()
 RETURNS date
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN date '2026-11-08';
END;
$function$;

DO $guard$
DECLARE
  v_cut date := public.agency_weekly_cutover_date();
BEGIN
  IF EXTRACT(DAY FROM v_cut)::int NOT IN (1, 8, 15, 22) THEN
    RAISE EXCEPTION 'agency_weekly_cutover_date % must be on day 1, 8, 15 or 22', v_cut;
  END IF;
  IF public.policy_local_now(now())::date >= v_cut THEN
    RAISE EXCEPTION 'agency_weekly_cutover_date % is not in the future (PK today %) — choose the next 1/8/15/22',
      v_cut, public.policy_local_now(now())::date;
  END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION public.agency_period_id_for_local_date(p_date date)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT to_char(p_date, 'YYYY-MM') || CASE
    WHEN p_date >= public.agency_weekly_cutover_date()
      THEN '-W' || LEAST(4, (EXTRACT(DAY FROM p_date)::int - 1) / 7 + 1)::text
    WHEN EXTRACT(DAY FROM p_date)::int <= 15 THEN '-A'
    ELSE '-B'
  END
$function$;

CREATE OR REPLACE FUNCTION public.agency_period_ids_in_month(p_month text)
 RETURNS text[]
 LANGUAGE sql
 STABLE
AS $function$
  SELECT array_agg(s.period_id ORDER BY s.first_day)
  FROM (
    SELECT public.agency_period_id_for_local_date(d::date) AS period_id, min(d::date) AS first_day
    FROM generate_series(
      to_date(p_month || '-01', 'YYYY-MM-DD'),
      (to_date(p_month || '-01', 'YYYY-MM-DD') + interval '1 month - 1 day')::date,
      interval '1 day'
    ) AS d
    GROUP BY 1
  ) s
$function$;

CREATE OR REPLACE FUNCTION public.get_period_id_for_ts(p_ts timestamp with time zone DEFAULT now())
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN public.agency_period_id_for_local_date(public.policy_local_now(p_ts)::date);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_period_bounds(p_period_id text)
 RETURNS TABLE(start_date date, end_date date, payout_date date)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_year int; v_month int; v_suffix text; v_first date; v_week int;
  v_cut date := public.agency_weekly_cutover_date();
BEGIN
  v_year  := split_part(p_period_id, '-', 1)::int;
  v_month := split_part(p_period_id, '-', 2)::int;
  v_suffix := upper(split_part(p_period_id, '-', 3));
  v_first := make_date(v_year, v_month, 1);

  IF v_suffix IN ('A', 'H1') THEN
    start_date  := v_first;
    end_date    := make_date(v_year, v_month, 15);
    payout_date := make_date(v_year, v_month, 16);
  ELSIF v_suffix IN ('B', 'H2') THEN
    start_date  := make_date(v_year, v_month, 16);
    end_date    := (v_first + interval '1 month - 1 day')::date;
    payout_date := (v_first + interval '1 month')::date;
  ELSIF v_suffix ~ '^W[1-4]$' THEN
    v_week      := substring(v_suffix from 2 for 1)::int;
    start_date  := make_date(v_year, v_month, 1 + 7 * (v_week - 1));
    end_date    := CASE WHEN v_week = 4
                     THEN (v_first + interval '1 month - 1 day')::date
                     ELSE start_date + 6 END;
    payout_date := end_date + 1;
  ELSE
    start_date  := v_first;
    end_date    := (v_first + interval '1 month - 1 day')::date;
    payout_date := (v_first + interval '1 month')::date;
  END IF;

  IF v_suffix IN ('A', 'H1', 'B', 'H2') AND v_cut > start_date AND v_cut <= end_date THEN
    end_date    := v_cut - 1;
    payout_date := v_cut;
  END IF;
  RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_previous_period_id(p_period_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_year int; v_month int; v_suffix text; v_prev date;
BEGIN
  v_year  := split_part(p_period_id, '-', 1)::int;
  v_month := split_part(p_period_id, '-', 2)::int;
  v_suffix := upper(split_part(p_period_id, '-', 3));

  IF v_suffix ~ '^W[1-4]$' THEN
    RETURN public.agency_period_id_for_local_date(
      (SELECT b.start_date FROM public.get_period_bounds(p_period_id) b) - 1
    );
  END IF;

  IF v_suffix IN ('B', 'H2') THEN
    RETURN to_char(make_date(v_year, v_month, 1), 'YYYY-MM') || '-A';
  END IF;

  v_prev := (make_date(v_year, v_month, 1) - interval '1 day')::date;

  IF v_suffix IN ('A', 'H1') THEN
    RETURN to_char(v_prev, 'YYYY-MM') || '-B';
  END IF;

  RETURN to_char(v_prev, 'YYYY-MM') || '-M';
END;
$function$;

CREATE OR REPLACE FUNCTION public.run_agency_period_payouts_at(p_now timestamp with time zone)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_today  date := public.policy_local_now(p_now)::date;
  v_day    int  := EXTRACT(DAY FROM v_today)::int;
  v_period text := public.agency_period_id_for_local_date(v_today - 1);
  v_res    json;
BEGIN
  IF v_period = public.agency_period_id_for_local_date(v_today) THEN
    RETURN json_build_object('ran', false, 'reason', 'not_payout_day', 'local_day', v_day);
  END IF;

  PERFORM public.ensure_salary_period(v_period);
  v_res := public.execute_agency_period_payout(v_period);
  RETURN json_build_object(
    'ran', true,
    'reason', 'period_ended',
    'local_day', v_day,
    'period', v_period,
    'result', v_res
  );
END;
$function$;

ALTER FUNCTION public.run_agency_period_payouts_at(timestamp with time zone) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.run_agency_period_payouts_at(timestamp with time zone) FROM PUBLIC;
DO $grants$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON FUNCTION public.run_agency_period_payouts_at(timestamp with time zone) FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON FUNCTION public.run_agency_period_payouts_at(timestamp with time zone) FROM authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION public.run_agency_period_payouts_at(timestamp with time zone) TO service_role;
  END IF;
END;
$grants$;

CREATE OR REPLACE FUNCTION public.run_scheduled_agency_period_payouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN public.run_agency_period_payouts_at(now());
END;
$function$;

CREATE OR REPLACE FUNCTION public.bd_period_ids_for(p_period text)
 RETURNS text[]
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_month text;
  v_ids   text[];
BEGIN
  IF p_period ~ '^\d{4}-\d{2}$' THEN
    v_month := p_period;
  ELSIF p_period ~ '^\d{4}-\d{2}-([A-Za-z]|[Ww][1-4])$' THEN
    v_month := substring(p_period from 1 for 7);
  ELSE
    RETURN ARRAY[p_period];
  END IF;

  IF EXISTS (SELECT 1 FROM public.salary_periods WHERE period_id = v_month || '-M') THEN
    RETURN ARRAY[v_month || '-M'];
  END IF;

  SELECT array_agg(period_id ORDER BY start_date) INTO v_ids
    FROM public.salary_periods
   WHERE period_id LIKE v_month || '-_'
     AND upper(right(period_id, 1)) <> 'M';

  RETURN COALESCE(v_ids, ARRAY[v_month || '-M']);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_agency_members_period_stats(p_agency_id uuid, p_period_id text DEFAULT NULL::text, p_user_id uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_period text;
  v_members json;
  v_today date;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.agencies a
    WHERE a.id = p_agency_id AND a.owner_id = v_uid
  ) AND NOT EXISTS (
    SELECT 1 FROM public.agency_members am
    WHERE am.agency_id = p_agency_id
      AND am.user_id = v_uid
      AND am.role IN ('owner', 'admin')
  ) THEN
    RETURN json_build_object('success', false, 'message', 'No access');
  END IF;

  v_period := COALESCE(p_period_id, public.get_period_id_for_date(current_date));

  v_today := public.policy_local_now(now())::date;
  IF p_period_id IS NOT NULL
     AND v_today >= public.agency_weekly_cutover_date()
     AND upper(btrim(p_period_id)) = (to_char(v_today, 'YYYY-MM')
         || (CASE WHEN EXTRACT(DAY FROM v_today)::int <= 15 THEN '-A' ELSE '-B' END)) THEN
    v_period := public.get_period_id_for_ts(now());
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_members
  FROM (
    SELECT
      am.user_id,
      COALESCE(hps.charm_points, 0) AS charm_points,
      COALESCE(hps.total_diamonds, 0) AS total_diamonds,
      COALESCE(hps.valid_days, 0) AS valid_days,
      COALESCE(hps.total_on_mic_seconds, 0) AS total_on_mic_seconds,
      hps.daily_seconds
    FROM public.agency_members am
    LEFT JOIN public.host_period_stats hps
      ON hps.user_id = am.user_id AND hps.period_id = v_period
    WHERE am.agency_id = p_agency_id
      AND (p_user_id IS NULL OR am.user_id = p_user_id)
  ) t;

  RETURN json_build_object(
    'success', true,
    'period_id', v_period,
    'members', v_members
  );
END;
$function$;

DO $patch$
DECLARE
  p record;
  v_def text;
  v_hits int;
BEGIN
  FOR p IN
    SELECT * FROM (VALUES
      (1, 'public.execute_agency_period_payout(text)'::regprocedure,
       $o$p_period_id !~ '^\d{4}-\d{2}-(A|B|M)$'$o$,
       $n$p_period_id !~ '^\d{4}-\d{2}-(A|B|M|W[1-4])$'$n$),
      (2, 'public.execute_agency_period_payout(text)'::regprocedure,
       $o$'Invalid period; expected YYYY-MM-A, YYYY-MM-B or YYYY-MM-M'$o$,
       $n$'Invalid period; expected YYYY-MM-A, YYYY-MM-B, YYYY-MM-M or YYYY-MM-W1..W4'$n$),
      (3, 'public.execute_one_agency_period_payout(text,uuid)'::regprocedure,
       $o$p_period_id !~ '^\d{4}-\d{2}-(A|B|M)$'$o$,
       $n$p_period_id !~ '^\d{4}-\d{2}-(A|B|M|W[1-4])$'$n$),
      (4, 'public.execute_one_agency_period_payout(text,uuid)'::regprocedure,
       $o$'Invalid period; expected YYYY-MM-A, YYYY-MM-B or YYYY-MM-M'$o$,
       $n$'Invalid period; expected YYYY-MM-A, YYYY-MM-B, YYYY-MM-M or YYYY-MM-W1..W4'$n$),
      (5, 'public.refresh_bd_monthly_stats(uuid,text)'::regprocedure,
       $o$  IF v_period !~ '^\d{4}-\d{2}-[ABM]$' THEN$o$,
       $n$  IF v_period ~ '^\d{4}-\d{2}-W[1-4]$' THEN
    v_period := substring(v_period from 1 for 7) || '-M';
  END IF;

  IF v_period !~ '^\d{4}-\d{2}-[ABM]$' THEN$n$),
      (6, 'public.refresh_bd_monthly_stats(uuid,text)'::regprocedure,
       $o$    SELECT COALESCE(SUM(ca.total_usd + cb.total_usd), 0)
    INTO v_target
    FROM public.agencies a
    CROSS JOIN LATERAL public.calculate_agency_period_salary_per_host(a.id, v_month || '-A') ca
    CROSS JOIN LATERAL public.calculate_agency_period_salary_per_host(a.id, v_month || '-B') cb$o$,
       $n$    SELECT COALESCE(SUM(c.total_usd), 0)
    INTO v_target
    FROM public.agencies a
    CROSS JOIN unnest(public.agency_period_ids_in_month(v_month)) AS mp(period_id)
    CROSS JOIN LATERAL public.calculate_agency_period_salary_per_host(a.id, mp.period_id) c$n$),
      (7, 'public.admin_agency_period_audit(text)'::regprocedure,
       $o$p_period_id !~ '^\d{4}-\d{2}-[ABMabm]$'$o$,
       $n$p_period_id !~ '^\d{4}-\d{2}-([ABMabm]|[Ww][1-4])$'$n$),
      (8, 'public.admin_host_period_audit(text)'::regprocedure,
       $o$p_period_id !~ '^\d{4}-\d{2}-[ABMabm]$'$o$,
       $n$p_period_id !~ '^\d{4}-\d{2}-([ABMabm]|[Ww][1-4])$'$n$)
    ) AS v(ord, fn, old_text, new_text)
    UNION ALL
    SELECT 100 + x.ord, x.fn,
      $o$  IF v_half NOT IN ('A', 'B') THEN
    v_start := make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC');
    v_end := (make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC') + interval '1 month');
  ELSIF v_half = 'A' THEN
    v_start := make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC');
    v_end := make_timestamptz(v_y, v_m, 16, 0, 0, 0, 'UTC');
  ELSE
    v_start := make_timestamptz(v_y, v_m, 16, 0, 0, 0, 'UTC');
    v_end := (make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC') + interval '1 month');
  END IF;$o$,
      $n$  IF upper(p_period_id) ~ '-(A|B|W[1-4])$' THEN
    SELECT (b.start_date::timestamp AT TIME ZONE 'UTC'),
           ((b.end_date + 1)::timestamp AT TIME ZONE 'UTC')
      INTO v_start, v_end
      FROM public.get_period_bounds(upper(p_period_id)) b;
  ELSE
    v_start := make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC');
    v_end := (make_timestamptz(v_y, v_m, 1, 0, 0, 0, 'UTC') + interval '1 month');
  END IF;$n$
    FROM (VALUES (1, 'public.admin_agency_period_audit(text)'::regprocedure),
                 (2, 'public.admin_host_period_audit(text)'::regprocedure)) AS x(ord, fn)
    ORDER BY 1
  LOOP
    v_def := pg_get_functiondef(p.fn);
    v_hits := (length(v_def) - length(replace(v_def, p.old_text, ''))) / length(p.old_text);
    IF v_hits <> 1 THEN
      RAISE EXCEPTION 'patch % on %: expected text found % times (live function differs) — aborting',
        p.ord, p.fn, v_hits;
    END IF;
    EXECUTE replace(v_def, p.old_text, p.new_text);
  END LOOP;
END;
$patch$;

UPDATE public.salary_periods sp
   SET end_date = b.end_date,
       payout_date = b.payout_date
  FROM public.get_period_bounds(
         public.agency_period_id_for_local_date(public.agency_weekly_cutover_date() - 1)
       ) b
 WHERE sp.period_id = public.agency_period_id_for_local_date(public.agency_weekly_cutover_date() - 1)
   AND sp.period_id ~ '-[AB]$'
   AND (sp.end_date, sp.payout_date) IS DISTINCT FROM (b.end_date, b.payout_date);

NOTIFY pgrst, 'reload schema';
