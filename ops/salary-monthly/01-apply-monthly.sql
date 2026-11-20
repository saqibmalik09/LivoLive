\set ON_ERROR_STOP on
\pset pager off
BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 1. One period per calendar month. Suffix 'M' = full month.
--    A/B stay valid so every historical period still resolves.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_period_id_for_ts(p_ts timestamp with time zone DEFAULT now())
 RETURNS text LANGUAGE plpgsql STABLE AS $fn$
DECLARE
  v_local timestamp;
BEGIN
  v_local := public.policy_local_now(p_ts);
  RETURN to_char(v_local, 'YYYY-MM') || '-M';
END;
$fn$;

-- 2. Bounds: 'M' spans the whole month and pays on the 1st of the next.
CREATE OR REPLACE FUNCTION public.get_period_bounds(p_period_id text)
 RETURNS TABLE(start_date date, end_date date, payout_date date)
 LANGUAGE plpgsql STABLE AS $fn$
DECLARE
  v_year int; v_month int; v_suffix text; v_first date;
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
  ELSE
    start_date  := v_first;
    end_date    := (v_first + interval '1 month - 1 day')::date;
    payout_date := (v_first + interval '1 month')::date;
  END IF;
  RETURN NEXT;
END;
$fn$;

-- 3. Previous period: monthly steps back a month; A/B keep half-month steps.
CREATE OR REPLACE FUNCTION public.get_previous_period_id(p_period_id text)
 RETURNS text LANGUAGE plpgsql STABLE AS $fn$
DECLARE
  v_year int; v_month int; v_suffix text; v_prev date;
BEGIN
  v_year  := split_part(p_period_id, '-', 1)::int;
  v_month := split_part(p_period_id, '-', 2)::int;
  v_suffix := upper(split_part(p_period_id, '-', 3));

  IF v_suffix IN ('B', 'H2') THEN
    RETURN to_char(make_date(v_year, v_month, 1), 'YYYY-MM') || '-A';
  END IF;

  v_prev := (make_date(v_year, v_month, 1) - interval '1 day')::date;

  IF v_suffix IN ('A', 'H1') THEN
    RETURN to_char(v_prev, 'YYYY-MM') || '-B';
  END IF;

  RETURN to_char(v_prev, 'YYYY-MM') || '-M';
END;
$fn$;

-- 4. Agency salary runs once, on the 1st, for the month just ended.
CREATE OR REPLACE FUNCTION public.run_scheduled_agency_period_payouts()
 RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_local timestamp := public.policy_local_now(now());
  v_day int := EXTRACT(DAY FROM v_local)::int;
  v_period text;
  v_prev date;
  v_res json;
BEGIN
  IF v_day = 1 THEN
    v_prev := (date_trunc('month', v_local::date) - interval '1 day')::date;
    v_period := to_char(v_prev, 'YYYY-MM') || '-M';
    PERFORM public.ensure_salary_period(v_period);
    v_res := public.execute_agency_period_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_1_prev_month', 'period', v_period, 'result', v_res);
  END IF;
  RETURN json_build_object('ran', false, 'reason', 'not_payout_day', 'local_day', v_day);
END;
$fn$;

-- 5. Same cadence for the BD chain.
CREATE OR REPLACE FUNCTION public.run_scheduled_bd_period_payouts()
 RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_local timestamp := public.policy_local_now(now());
  v_day int := EXTRACT(DAY FROM v_local)::int;
  v_period text;
  v_prev date;
  v_res json;
BEGIN
  IF v_day = 1 THEN
    v_prev := (date_trunc('month', v_local::date) - interval '1 day')::date;
    v_period := to_char(v_prev, 'YYYY-MM') || '-M';
    v_res := public.execute_bd_monthly_payout(v_period);
    RETURN json_build_object('ran', true, 'reason', 'day_1_prev_month', 'period', v_period, 'result', v_res);
  END IF;
  RETURN json_build_object('ran', false, 'reason', 'not_payout_day', 'local_day', v_day);
END;
$fn$;

-- ─────────────────────────────────────────────────────────────
-- 6. Widen the A/B-only guards so a monthly id is accepted, and
--    point the legacy bare-YYYY-MM coercion at the month.
-- ─────────────────────────────────────────────────────────────
DO $mig$
DECLARE
  r record;
  v_def text;
  v_new text;
  v_count int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname IN (
      'execute_agency_period_payout','execute_one_agency_period_payout',
      'execute_bd_monthly_payout','execute_one_bd_monthly_payout',
      'refresh_bd_monthly_stats','admin_bd_month_audit',
      'admin_agency_period_audit','admin_host_period_audit')
  LOOP
    v_def := pg_get_functiondef(r.oid);
    v_new := v_def;
    v_new := replace(v_new, '-(A|B)$',   '-(A|B|M)$');
    v_new := replace(v_new, '-[AB]$',    '-[ABM]$');
    v_new := replace(v_new, '-[ABab]$',  '-[ABMabm]$');
    v_new := replace(v_new, 'YYYY-MM-A|B', 'YYYY-MM-A|B|M');
    v_new := replace(v_new, 'YYYY-MM-A or YYYY-MM-B', 'YYYY-MM-A, YYYY-MM-B or YYYY-MM-M');
    v_new := replace(v_new, 'v_period := v_period || ''-B'';', 'v_period := v_period || ''-M'';');
    -- audits derive bounds from the half flag; give the month its own branch
    v_new := replace(v_new,
      'IF v_half = ''A'' THEN',
      'IF v_half NOT IN (''A'', ''B'') THEN' || chr(10) ||
      '    v_start := make_timestamptz(v_y, v_m, 1, 0, 0, 0, ''UTC'');' || chr(10) ||
      '    v_end := (make_timestamptz(v_y, v_m, 1, 0, 0, 0, ''UTC'') + interval ''1 month'');' || chr(10) ||
      '  ELSIF v_half = ''A'' THEN');
    IF v_new = v_def THEN
      RAISE EXCEPTION 'guard widening matched nothing in %', r.proname;
    END IF;
    EXECUTE v_new;
    v_count := v_count + 1;
  END LOOP;
  RAISE NOTICE 'widened % functions', v_count;
END
$mig$;

-- ─────────────────────────────────────────────────────────────
-- 7. Carry the in-flight period over: 2026-10-A (open, unpaid,
--    1-2 Oct accrued) becomes the first full monthly period.
-- ─────────────────────────────────────────────────────────────
-- Child tables carry a foreign key to salary_periods, so the new period has
-- to exist before anything can point at it, and the old one can only go once
-- nothing references it. Renaming in place fails on the constraint.
INSERT INTO public.salary_periods (period_id, start_date, end_date, payout_date, status)
SELECT '2026-10-M', '2026-10-01', '2026-10-31', '2026-11-01', status
FROM public.salary_periods WHERE period_id = '2026-10-A'
ON CONFLICT (period_id) DO NOTHING;

UPDATE public.host_period_stats          SET period_id = '2026-10-M' WHERE period_id = '2026-10-A';
UPDATE public.agency_period_settlements  SET period_id = '2026-10-M' WHERE period_id = '2026-10-A';
UPDATE public.host_salary_payouts        SET period_id = '2026-10-M' WHERE period_id = '2026-10-A';
UPDATE public.sk_host_party_claims       SET period_id = '2026-10-M' WHERE period_id = '2026-10-A';

DELETE FROM public.salary_periods WHERE period_id = '2026-10-A';

-- BD stats are rebuilt from source after this file, by calling
-- refresh_bd_monthly_stats('<month>-M'). Renaming the half rows in place
-- would collide: a staff member with both -A and -B for one month would end
-- up with two rows claiming the same monthly period, and summing them by hand
-- risks double-counting agencies that appear in both halves.

COMMIT;
