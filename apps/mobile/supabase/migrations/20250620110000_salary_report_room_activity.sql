-- Rewrite report_room_activity for bi-monthly period stats + valid days

CREATE OR REPLACE FUNCTION public.report_room_activity(p_room_id uuid, p_is_on_mic boolean)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_user_id uuid;
    v_period_id text;
    v_day_key text;
    v_cfg record;
    v_stats record;
    v_prev_day_seconds int;
    v_new_daily int;
    v_min_seconds int;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    SELECT * INTO v_cfg FROM public.salary_chain_configs WHERE id = 1;
    v_min_seconds := COALESCE(v_cfg.min_valid_day_seconds, 7200);

    IF COALESCE(v_cfg.on_mic_only, true) AND NOT COALESCE(p_is_on_mic, false) THEN
        RETURN json_build_object('success', true, 'skipped', 'not_on_mic');
    END IF;

    v_period_id := public.get_period_id_for_date(current_date);
    PERFORM public.ensure_salary_period(v_period_id);
    v_day_key := extract(day FROM current_date)::text;

    SELECT * INTO v_stats
    FROM public.host_period_stats
    WHERE user_id = v_user_id AND period_id = v_period_id
    FOR UPDATE;

    IF v_stats.user_id IS NULL THEN
        INSERT INTO public.host_period_stats (
            user_id, period_id, total_on_mic_seconds, daily_seconds, last_active_date
        )
        VALUES (
            v_user_id, v_period_id, 60,
            jsonb_build_object(v_day_key, 60),
            current_date
        );
    ELSE
        IF v_stats.last_active_date IS DISTINCT FROM current_date THEN
            IF v_stats.last_active_date IS NOT NULL THEN
                v_prev_day_seconds := COALESCE(
                    (v_stats.daily_seconds -> extract(day FROM v_stats.last_active_date)::text)::int,
                    0
                );
                IF v_prev_day_seconds >= v_min_seconds THEN
                    UPDATE public.host_period_stats
                    SET valid_days = valid_days + 1
                    WHERE user_id = v_user_id AND period_id = v_period_id;
                END IF;
            END IF;

            UPDATE public.host_period_stats
            SET
                total_on_mic_seconds = total_on_mic_seconds + 60,
                daily_seconds = jsonb_set(
                    COALESCE(daily_seconds, '{}'::jsonb),
                    ARRAY[v_day_key],
                    to_jsonb(60),
                    true
                ),
                last_active_date = current_date,
                updated_at = now()
            WHERE user_id = v_user_id AND period_id = v_period_id;
        ELSE
            v_new_daily := COALESCE((v_stats.daily_seconds -> v_day_key)::int, 0) + 60;
            UPDATE public.host_period_stats
            SET
                total_on_mic_seconds = total_on_mic_seconds + 60,
                daily_seconds = jsonb_set(
                    COALESCE(daily_seconds, '{}'::jsonb),
                    ARRAY[v_day_key],
                    to_jsonb(v_new_daily),
                    true
                ),
                updated_at = now()
            WHERE user_id = v_user_id AND period_id = v_period_id;
        END IF;
    END IF;

    -- Backward compat: weekly stats
    INSERT INTO public.host_weekly_stats (user_id, week_id, daily_seconds, total_seconds, last_active_date)
    VALUES (v_user_id, to_char(current_date, 'IYYY-IW'), 60, 60, current_date)
    ON CONFLICT (user_id, week_id) DO UPDATE SET
        daily_seconds = CASE
            WHEN public.host_weekly_stats.last_active_date < current_date THEN 60
            ELSE public.host_weekly_stats.daily_seconds + 60
        END,
        total_seconds = public.host_weekly_stats.total_seconds + 60,
        last_active_date = current_date,
        updated_at = now();

    RETURN json_build_object('success', true, 'period_id', v_period_id);
END;
$function$;
