-- Fix staff-owned agencies missing sponsor link + portal visibility

-- 1. Link legacy agencies to owner's active staff record
UPDATE public.agencies a
SET
    sponsor_staff_id = bs.id,
    approved_by_staff_id = COALESCE(a.approved_by_staff_id, bs.id)
FROM public.business_staff bs
WHERE a.owner_id = bs.user_id
  AND bs.is_active = true
  AND a.sponsor_staff_id IS NULL;

CREATE OR REPLACE FUNCTION public.get_my_owned_agency()
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
    SELECT COALESCE((
        SELECT json_build_object(
            'id', a.id,
            'name', a.name,
            'agency_code', a.agency_code,
            'is_active', a.is_active,
            'owner_id', a.owner_id,
            'sponsor_staff_id', a.sponsor_staff_id
        )
        FROM public.agencies a
        WHERE a.owner_id = auth.uid()
          AND a.is_active = true
        ORDER BY a.created_at DESC
        LIMIT 1
    ), 'null'::json);
$$;

GRANT EXECUTE ON FUNCTION public.get_my_owned_agency() TO authenticated;

-- 2. Include Super BD's own agency even if sponsor was never set
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
