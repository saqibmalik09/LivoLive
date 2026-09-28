-- Super BD dashboard chart analytics

CREATE OR REPLACE FUNCTION public.get_super_bd_chart_analytics()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_root_id uuid;
    v_me_user_id uuid;
    v_period_id text;
BEGIN
    v_root_id := public.assert_super_bd();
    v_period_id := public.get_period_id_for_date(current_date);

    SELECT user_id INTO v_me_user_id
    FROM public.business_staff WHERE id = v_root_id;

    RETURN json_build_object(
        'period_id', v_period_id,
        'commission_trend', COALESCE((
            SELECT json_agg(row_to_json(t) ORDER BY t.day)
            FROM (
                SELECT
                    to_char(d.day, 'Mon DD') AS label,
                    d.day::text AS day,
                    COALESCE(SUM(el.super_bd_amount), 0)::int AS diamonds
                FROM generate_series(
                    (current_date - interval '13 days')::date,
                    current_date,
                    interval '1 day'
                ) AS d(day)
                LEFT JOIN public.earning_logs el
                    ON el.super_bd_staff_id = v_root_id
                    AND el.created_at >= d.day
                    AND el.created_at < d.day + interval '1 day'
                GROUP BY d.day
            ) t
        ), '[]'::json),
        'agency_performance', COALESCE((
            SELECT json_agg(row_to_json(t) ORDER BY t.diamonds DESC)
            FROM (
                SELECT
                    a.name,
                    a.agency_code,
                    COUNT(am.user_id)::int AS hosts,
                    COALESCE(SUM(hps.total_diamonds), 0)::int AS diamonds,
                    COALESCE(SUM(hps.total_on_mic_seconds), 0)::int AS on_mic_seconds
                FROM public.agencies a
                LEFT JOIN public.agency_members am ON am.agency_id = a.id
                LEFT JOIN public.host_period_stats hps
                    ON hps.user_id = am.user_id AND hps.period_id = v_period_id
                WHERE a.is_active = true
                  AND (
                    a.sponsor_staff_id IN (SELECT staff_id FROM public.get_staff_subtree_ids(v_root_id))
                    OR a.owner_id = v_me_user_id
                  )
                GROUP BY a.id, a.name, a.agency_code
            ) t
        ), '[]'::json),
        'top_hosts', COALESCE((
            SELECT json_agg(row_to_json(t) ORDER BY t.diamonds DESC)
            FROM (
                SELECT
                    u.username,
                    u.short_id,
                    a.name AS agency_name,
                    COALESCE(hps.total_diamonds, 0)::int AS diamonds,
                    COALESCE(hps.total_on_mic_seconds, 0)::int AS on_mic_seconds,
                    COALESCE(hps.valid_days, 0)::int AS valid_days
                FROM public.agency_members am
                JOIN public.users u ON u.id = am.user_id
                JOIN public.agencies a ON a.id = am.agency_id
                LEFT JOIN public.host_period_stats hps
                    ON hps.user_id = am.user_id AND hps.period_id = v_period_id
                WHERE a.is_active = true
                  AND (
                    a.sponsor_staff_id IN (SELECT staff_id FROM public.get_staff_subtree_ids(v_root_id))
                    OR a.owner_id = v_me_user_id
                  )
                ORDER BY COALESCE(hps.total_diamonds, 0) DESC
                LIMIT 10
            ) t
        ), '[]'::json),
        'role_breakdown', COALESCE((
            SELECT json_agg(row_to_json(t))
            FROM (
                SELECT
                    CASE bs.role
                        WHEN 'bd_admin' THEN 'BD Admin'
                        WHEN 'bd' THEN 'BD'
                        WHEN 'super_bd' THEN 'Super BD'
                        ELSE bs.role
                    END AS role,
                    COUNT(*)::int AS count
                FROM public.business_staff bs
                WHERE bs.id IN (SELECT staff_id FROM public.get_staff_subtree_ids(v_root_id))
                  AND bs.is_active = true
                GROUP BY bs.role
            ) t
        ), '[]'::json)
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_super_bd_chart_analytics() TO authenticated;
