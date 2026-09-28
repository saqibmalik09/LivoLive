-- Host Center: get_current_period_info was STABLE but calls ensure_salary_period (INSERT).
-- PostgREST runs STABLE RPCs in a read-only transaction → "cannot execute INSERT in a read-only transaction".

CREATE OR REPLACE FUNCTION public.ensure_salary_period(p_period_id text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    b record;
BEGIN
    SELECT * INTO b FROM public.get_period_bounds(p_period_id);
    INSERT INTO public.salary_periods (period_id, start_date, end_date, payout_date, status)
    VALUES (p_period_id, b.start_date, b.end_date, b.payout_date, 'open')
    ON CONFLICT (period_id) DO NOTHING;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_current_period_info()
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_period_id text;
    b record;
BEGIN
    v_period_id := public.get_period_id_for_date(current_date);
    PERFORM public.ensure_salary_period(v_period_id);
    SELECT * INTO b FROM public.get_period_bounds(v_period_id);
    RETURN json_build_object(
        'period_id', v_period_id,
        'start_date', b.start_date,
        'end_date', b.end_date,
        'payout_date', b.payout_date
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_current_period_info() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_period_info() TO service_role;
