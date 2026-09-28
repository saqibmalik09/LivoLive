-- Super BD portal: hierarchy dashboard, subtree applications, user search

-- ---------------------------------------------------------------------------
-- 1. Helper: get caller's active super_bd staff row id
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_super_bd_staff_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
    SELECT id
    FROM public.business_staff
    WHERE user_id = auth.uid()
      AND role = 'super_bd'
      AND is_active = true
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.assert_super_bd()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_id uuid;
BEGIN
    v_id := public.get_my_super_bd_staff_id();
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized: active Super BD role required';
    END IF;
    RETURN v_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. All staff ids in subtree (including self)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_staff_subtree_ids(p_root_staff_id uuid)
RETURNS TABLE(staff_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
    WITH RECURSIVE subtree AS (
        SELECT id
        FROM public.business_staff
        WHERE id = p_root_staff_id AND is_active = true
        UNION ALL
        SELECT bs.id
        FROM public.business_staff bs
        INNER JOIN subtree s ON bs.parent_staff_id = s.id
        WHERE bs.is_active = true
    )
    SELECT id FROM subtree;
$$;

-- ---------------------------------------------------------------------------
-- 3. Full hierarchy tree for Super BD portal
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_super_bd_hierarchy()
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
    v_root_id := public.assert_super_bd();
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

    SELECT COALESCE(sum(el.super_bd_amount), 0)::bigint INTO v_commission_total
    FROM public.earning_logs el
    WHERE el.super_bd_staff_id = v_root_id;

    SELECT COALESCE(sum(hsp.total_amount), 0)::bigint INTO v_salary_total
    FROM public.host_salary_payouts hsp
    WHERE hsp.beneficiary_user_id = v_me.user_id
      AND hsp.beneficiary_role = 'super_bd'
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
             WHERE a.sponsor_staff_id = st.id AND a.is_active = true) AS direct_agency_count
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
          AND a.sponsor_staff_id IN (SELECT staff_id FROM public.get_staff_subtree_ids(v_root_id))
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

-- ---------------------------------------------------------------------------
-- 4. Pending agency applications in subtree
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
    v_root_id := public.assert_super_bd();

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
-- 5. User search for staff creation (Super BD only)
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
BEGIN
    PERFORM public.assert_super_bd();
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

GRANT EXECUTE ON FUNCTION public.get_super_bd_hierarchy() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_subtree_agency_applications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_users_for_staff_creation(text) TO authenticated;
