-- Admin: zero current-period host target progress (all users or one user).

CREATE OR REPLACE FUNCTION public.admin_reset_period_targets(
  p_scope text DEFAULT 'all',          -- 'all' | 'user'
  p_user_id uuid DEFAULT NULL,
  p_short_id bigint DEFAULT NULL,
  p_period_id text DEFAULT NULL        -- NULL = current open period
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_period text;
  v_user_id uuid;
  v_username text;
  v_short_id bigint;
  v_rows int := 0;
  v_bd_rows int := 0;
  v_month text;
  r record;
BEGIN
  -- Platform admin (service_role) or DB superuser only.
  IF auth.role() IS DISTINCT FROM 'service_role'
     AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  v_period := COALESCE(NULLIF(btrim(p_period_id), ''), public.get_period_id_for_date(current_date));
  PERFORM public.ensure_salary_period(v_period);

  IF lower(COALESCE(p_scope, 'all')) = 'user' THEN
    IF p_user_id IS NOT NULL THEN
      v_user_id := p_user_id;
    ELSIF p_short_id IS NOT NULL THEN
      SELECT id INTO v_user_id FROM public.users WHERE short_id = p_short_id LIMIT 1;
    ELSE
      RETURN json_build_object('success', false, 'message', 'user_id or short_id required');
    END IF;

    IF v_user_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'User not found');
    END IF;

    SELECT username, short_id INTO v_username, v_short_id
    FROM public.users WHERE id = v_user_id;

    UPDATE public.host_period_stats
    SET
      total_diamonds = 0,
      charm_points = 0,
      total_on_mic_seconds = 0,
      valid_days = 0,
      daily_seconds = '{}'::jsonb,
      last_active_date = NULL,
      updated_at = now()
    WHERE user_id = v_user_id
      AND period_id = v_period;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    -- If no row yet, insert a clean zero row so UI shows 0 immediately.
    IF v_rows = 0 THEN
      INSERT INTO public.host_period_stats (
        user_id, period_id, total_diamonds, charm_points,
        total_on_mic_seconds, valid_days, daily_seconds, last_active_date
      ) VALUES (
        v_user_id, v_period, 0, 0, 0, 0, '{}'::jsonb, NULL
      )
      ON CONFLICT (user_id, period_id) DO UPDATE SET
        total_diamonds = 0,
        charm_points = 0,
        total_on_mic_seconds = 0,
        valid_days = 0,
        daily_seconds = '{}'::jsonb,
        last_active_date = NULL,
        updated_at = now();
      v_rows := 1;
    END IF;

    -- Refresh BD monthly cache if this user is staff (progress recomputed from hosts).
    v_month := to_char(current_date, 'YYYY-MM');
    FOR r IN
      SELECT bs.id
      FROM public.business_staff bs
      WHERE bs.user_id = v_user_id AND bs.is_active
    LOOP
      PERFORM public.refresh_bd_monthly_stats(r.id, v_month);
      v_bd_rows := v_bd_rows + 1;
    END LOOP;

    RETURN json_build_object(
      'success', true,
      'message', format('Reset targets for %s (#%s) in period %s', COALESCE(v_username, 'user'), COALESCE(v_short_id::text, '—'), v_period),
      'scope', 'user',
      'period_id', v_period,
      'user_id', v_user_id,
      'short_id', v_short_id,
      'rows_updated', v_rows,
      'bd_refreshed', v_bd_rows
    );
  END IF;

  -- ALL users: current period only
  UPDATE public.host_period_stats
  SET
    total_diamonds = 0,
    charm_points = 0,
    total_on_mic_seconds = 0,
    valid_days = 0,
    daily_seconds = '{}'::jsonb,
    last_active_date = NULL,
    updated_at = now()
  WHERE period_id = v_period;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  -- Zero BD monthly cache for current calendar month (will refill on next refresh).
  v_month := to_char(current_date, 'YYYY-MM');
  UPDATE public.bd_staff_monthly_stats
  SET
    agency_target_usd = 0,
    work_days = 0,
    work_hours = 0,
    new_agencies = 0,
    achieved_level = 0,
    est_basic_usd = 0,
    est_commission_usd = 0,
    est_new_bd_usd = 0,
    est_total_usd = 0,
    last_calculated_at = now()
  WHERE period_yyyy_mm = v_month;
  GET DIAGNOSTICS v_bd_rows = ROW_COUNT;

  RETURN json_build_object(
    'success', true,
    'message', format('Reset all host targets for period %s (%s rows)', v_period, v_rows),
    'scope', 'all',
    'period_id', v_period,
    'rows_updated', v_rows,
    'bd_rows_updated', v_bd_rows
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_reset_period_targets(text, uuid, bigint, text)
  TO service_role;
