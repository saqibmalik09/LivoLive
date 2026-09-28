-- Staff Portal RBAC: Super BD, BD Admin, and BD web access

-- ---------------------------------------------------------------------------
-- 1. Portal staff helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_my_portal_staff_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
    SELECT id
    FROM public.business_staff
    WHERE user_id = auth.uid()
      AND role IN ('super_bd', 'bd_admin', 'bd')
      AND is_active = true
    ORDER BY created_at DESC
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.assert_portal_staff()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_id uuid;
BEGIN
    v_id := public.get_my_portal_staff_id();
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized: active staff role required';
    END IF;
    RETURN v_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_my_portal_staff_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assert_portal_staff() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Extended gate RPC
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_my_staff_gate_info()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_profile record;
    v_staff record;
    v_portal_id uuid;
    v_super_id uuid;
    v_child_role text;
BEGIN
    IF v_uid IS NULL THEN
        RETURN json_build_object('authenticated', false);
    END IF;

    SELECT username, short_id INTO v_profile
    FROM public.users WHERE id = v_uid;

    SELECT role, staff_code, is_active, id INTO v_staff
    FROM public.business_staff
    WHERE user_id = v_uid AND is_active = true
    ORDER BY created_at DESC
    LIMIT 1;

    v_portal_id := public.get_my_portal_staff_id();
    v_super_id := public.get_my_super_bd_staff_id();
    v_child_role := CASE WHEN v_staff.role IS NOT NULL
        THEN public.business_staff_child_role(v_staff.role)
        ELSE NULL
    END;

    RETURN json_build_object(
        'authenticated', true,
        'user_id', v_uid,
        'username', v_profile.username,
        'short_id', v_profile.short_id,
        'staff_id', v_portal_id,
        'staff_role', v_staff.role,
        'staff_code', v_staff.staff_code,
        'can_access_portal', v_portal_id IS NOT NULL,
        'child_role', v_child_role,
        'is_super_bd', v_super_id IS NOT NULL,
        'super_bd_staff_id', v_super_id
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Shared hierarchy implementation (portal staff subtree)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_staff_portal_hierarchy()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_root_id uuid;
    v_me record;
    v_period_id text;
    v_pending_apps int;
    v_commission_total bigint;
    v_salary_total bigint;
    v_tree jsonb;
BEGIN
    v_root_id := public.assert_portal_staff();
    v_period_id := public.get_period_id_for_date(current_date);

    SELECT bs.id, bs.role, bs.staff_code, bs.is_active, bs.user_id,
           u.username, u.short_id, u.avatar_url, u.diamonds
    INTO v_me
    FROM public.business_staff bs
    JOIN public.users u ON u.id = bs.user_id
    WHERE bs.id = v_root_id;

    SELECT count(*)::int INTO v_pending_apps
    FROM public.user_applications ua
    WHERE ua.type = 'agency'
      AND ua.status = 'pending'
      AND ua.target_staff_id IN (SELECT staff_id FROM public.get_staff_subtree_ids(v_root_id));

    IF v_me.role = 'super_bd' THEN
        SELECT COALESCE(sum(el.super_bd_amount), 0)::bigint INTO v_commission_total
        FROM public.earning_logs el
        WHERE el.super_bd_staff_id = v_root_id;
    ELSIF v_me.role = 'bd_admin' THEN
        SELECT COALESCE(sum(el.bd_admin_amount), 0)::bigint INTO v_commission_total
        FROM public.earning_logs el
        WHERE el.bd_admin_staff_id = v_root_id;
    ELSE
        SELECT COALESCE(sum(el.bd_amount), 0)::bigint INTO v_commission_total
        FROM public.earning_logs el
        WHERE el.bd_staff_id = v_root_id;
    END IF;

    SELECT COALESCE(sum(hsp.total_amount), 0)::bigint INTO v_salary_total
    FROM public.host_salary_payouts hsp
    WHERE hsp.beneficiary_user_id = v_me.user_id
      AND hsp.beneficiary_role = v_me.role
      AND hsp.status = 'paid';

    WITH RECURSIVE staff_tree AS (
        SELECT
            bs.id,
            bs.parent_staff_id,
            bs.role,
            bs.staff_code,
            bs.is_active,
            bs.user_id,
            u.username,
            u.short_id,
            u.avatar_url,
            0 AS depth
        FROM public.business_staff bs
        JOIN public.users u ON u.id = bs.user_id
        WHERE bs.id = v_root_id
        UNION ALL
        SELECT
            bs.id,
            bs.parent_staff_id,
            bs.role,
            bs.staff_code,
            bs.is_active,
            bs.user_id,
            u.username,
            u.short_id,
            u.avatar_url,
            st.depth + 1
        FROM public.business_staff bs
        JOIN public.users u ON u.id = bs.user_id
        INNER JOIN staff_tree st ON bs.parent_staff_id = st.id
        WHERE bs.is_active = true
    ),
    staff_with_counts AS (
        SELECT
            st.*,
            (SELECT count(*)::int FROM public.business_staff c
             WHERE c.parent_staff_id = st.id AND c.is_active = true) AS direct_team_count,
            (SELECT count(*)::int FROM public.agencies a
             WHERE a.is_active = true
               AND (a.sponsor_staff_id = st.id OR a.owner_id = st.user_id)) AS direct_agency_count
        FROM staff_tree st
        WHERE st.id <> v_root_id OR st.depth = 0
    ),
    agencies_under_subtree AS (
        SELECT
            a.id,
            a.name,
            a.agency_code,
            a.is_active,
            a.owner_id,
            a.sponsor_staff_id,
            a.created_at,
            ou.username AS owner_username,
            ou.short_id AS owner_short_id,
            ou.avatar_url AS owner_avatar_url,
            su.username AS sponsor_username,
            bs.role AS sponsor_role
        FROM public.agencies a
        JOIN public.users ou ON ou.id = a.owner_id
        LEFT JOIN public.business_staff bs ON bs.id = a.sponsor_staff_id
        LEFT JOIN public.users su ON su.id = bs.user_id
        WHERE a.is_active = true
          AND (
            a.sponsor_staff_id IN (SELECT staff_id FROM public.get_staff_subtree_ids(v_root_id))
            OR a.owner_id = v_me.user_id
          )
    ),
    hosts_under_subtree AS (
        SELECT
            am.id AS member_id,
            am.agency_id,
            am.user_id,
            am.joined_at,
            u.username,
            u.short_id,
            u.avatar_url,
            hps.total_diamonds,
            hps.total_on_mic_seconds,
            hps.valid_days
        FROM public.agency_members am
        JOIN public.users u ON u.id = am.user_id
        JOIN agencies_under_subtree a ON a.id = am.agency_id
        LEFT JOIN public.host_period_stats hps
            ON hps.user_id = am.user_id AND hps.period_id = v_period_id
    )
    SELECT jsonb_build_object(
        'staff', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', sc.id,
                    'parent_staff_id', sc.parent_staff_id,
                    'role', sc.role,
                    'staff_code', sc.staff_code,
                    'is_active', sc.is_active,
                    'user_id', sc.user_id,
                    'username', sc.username,
                    'short_id', sc.short_id,
                    'avatar_url', sc.avatar_url,
                    'depth', sc.depth,
                    'direct_team_count', sc.direct_team_count,
                    'direct_agency_count', sc.direct_agency_count
                )
                ORDER BY sc.depth, sc.role, sc.username
            )
            FROM staff_with_counts sc
        ), '[]'::jsonb),
        'agencies', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', a.id,
                    'name', a.name,
                    'agency_code', a.agency_code,
                    'is_active', a.is_active,
                    'owner_id', a.owner_id,
                    'owner_username', a.owner_username,
                    'owner_short_id', a.owner_short_id,
                    'owner_avatar_url', a.owner_avatar_url,
                    'sponsor_staff_id', a.sponsor_staff_id,
                    'sponsor_username', a.sponsor_username,
                    'sponsor_role', a.sponsor_role,
                    'created_at', a.created_at,
                    'host_count', (SELECT count(*)::int FROM hosts_under_subtree h WHERE h.agency_id = a.id)
                )
                ORDER BY a.created_at DESC
            )
            FROM agencies_under_subtree a
        ), '[]'::jsonb),
        'hosts', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'member_id', h.member_id,
                    'agency_id', h.agency_id,
                    'user_id', h.user_id,
                    'username', h.username,
                    'short_id', h.short_id,
                    'avatar_url', h.avatar_url,
                    'joined_at', h.joined_at,
                    'period_diamonds', COALESCE(h.total_diamonds, 0),
                    'period_on_mic_seconds', COALESCE(h.total_on_mic_seconds, 0),
                    'period_valid_days', COALESCE(h.valid_days, 0)
                )
                ORDER BY h.joined_at DESC
            )
            FROM hosts_under_subtree h
        ), '[]'::jsonb)
    ) INTO v_tree;

    RETURN json_build_object(
        'success', true,
        'me', json_build_object(
            'staff_id', v_me.id,
            'role', v_me.role,
            'staff_code', v_me.staff_code,
            'is_active', v_me.is_active,
            'user_id', v_me.user_id,
            'username', v_me.username,
            'short_id', v_me.short_id,
            'avatar_url', v_me.avatar_url,
            'diamonds', v_me.diamonds
        ),
        'period_id', v_period_id,
        'stats', json_build_object(
            'bd_admin_count', (SELECT count(*)::int FROM jsonb_array_elements(v_tree->'staff') e
                WHERE e->>'role' = 'bd_admin'),
            'bd_count', (SELECT count(*)::int FROM jsonb_array_elements(v_tree->'staff') e
                WHERE e->>'role' = 'bd'),
            'agency_count', jsonb_array_length(COALESCE(v_tree->'agencies', '[]'::jsonb)),
            'host_count', jsonb_array_length(COALESCE(v_tree->'hosts', '[]'::jsonb)),
            'pending_applications', v_pending_apps,
            'commission_diamonds', v_commission_total,
            'salary_diamonds', v_salary_total
        ),
        'tree', v_tree
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_super_bd_hierarchy()
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
    SELECT public.get_staff_portal_hierarchy();
$$;

GRANT EXECUTE ON FUNCTION public.get_staff_portal_hierarchy() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Subtree applications (portal staff)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_subtree_agency_applications()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_root_id uuid;
BEGIN
    v_root_id := public.assert_portal_staff();

    RETURN COALESCE((
        SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC)
        FROM (
            SELECT
                ua.id,
                ua.user_id,
                ua.real_name,
                ua.status,
                ua.created_at,
                ua.target_staff_id,
                u.username,
                u.short_id,
                u.avatar_url,
                ts.staff_code AS target_staff_code,
                ts.role AS target_staff_role,
                tu.username AS target_staff_username
            FROM public.user_applications ua
            JOIN public.users u ON u.id = ua.user_id
            LEFT JOIN public.business_staff ts ON ts.id = ua.target_staff_id
            LEFT JOIN public.users tu ON tu.id = ts.user_id
            WHERE ua.type = 'agency'
              AND ua.status = 'pending'
              AND ua.target_staff_id IN (
                  SELECT staff_id FROM public.get_staff_subtree_ids(v_root_id)
              )
        ) t
    ), '[]'::json);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. User search for staff creation (Super BD + BD Admin only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.search_users_for_staff_creation(p_query text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_trimmed text;
    v_staff record;
BEGIN
    SELECT bs.id, bs.role INTO v_staff
    FROM public.business_staff bs
    WHERE bs.id = public.assert_portal_staff();

    IF public.business_staff_child_role(v_staff.role) IS NULL THEN
        RAISE EXCEPTION 'Not authorized: cannot create staff at your role level';
    END IF;

    v_trimmed := trim(p_query);
    IF v_trimmed = '' THEN
        RETURN '[]'::json;
    END IF;

    IF v_trimmed ~ '^\d+$' THEN
        RETURN COALESCE((
            SELECT json_agg(row_to_json(t))
            FROM (
                SELECT u.id, u.username, u.short_id, u.avatar_url
                FROM public.users u
                WHERE u.short_id = v_trimmed::int
                LIMIT 8
            ) t
        ), '[]'::json);
    END IF;

    RETURN COALESCE((
        SELECT json_agg(row_to_json(t))
        FROM (
            SELECT u.id, u.username, u.short_id, u.avatar_url
            FROM public.users u
            WHERE u.username ILIKE '%' || v_trimmed || '%'
            ORDER BY u.username
            LIMIT 8
        ) t
    ), '[]'::json);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Chart analytics (portal staff, role-dynamic commission)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_super_bd_chart_analytics()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_root_id uuid;
    v_me_role text;
    v_me_user_id uuid;
    v_period_id text;
BEGIN
    v_root_id := public.assert_portal_staff();
    v_period_id := public.get_period_id_for_date(current_date);

    SELECT role, user_id INTO v_me_role, v_me_user_id
    FROM public.business_staff WHERE id = v_root_id;

    RETURN json_build_object(
        'period_id', v_period_id,
        'commission_trend', COALESCE((
            SELECT json_agg(row_to_json(t) ORDER BY t.day)
            FROM (
                SELECT
                    to_char(d.day, 'Mon DD') AS label,
                    d.day::text AS day,
                    CASE v_me_role
                        WHEN 'super_bd' THEN COALESCE(SUM(el.super_bd_amount), 0)::int
                        WHEN 'bd_admin' THEN COALESCE(SUM(el.bd_admin_amount), 0)::int
                        ELSE COALESCE(SUM(el.bd_amount), 0)::int
                    END AS diamonds
                FROM generate_series(
                    (current_date - interval '13 days')::date,
                    current_date,
                    interval '1 day'
                ) AS d(day)
                LEFT JOIN public.earning_logs el
                    ON (
                        (v_me_role = 'super_bd' AND el.super_bd_staff_id = v_root_id)
                        OR (v_me_role = 'bd_admin' AND el.bd_admin_staff_id = v_root_id)
                        OR (v_me_role = 'bd' AND el.bd_staff_id = v_root_id)
                    )
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
