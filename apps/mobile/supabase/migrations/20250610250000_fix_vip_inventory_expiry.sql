-- Fix VIP inventory not refreshing on re-purchase (e.g. entrance show stuck as Expired).
-- Root cause: provision_user_assets only matched source_type='vip' with required_vip_level>0.
-- Some VIP cosmetics (entrance show) use name ILIKE 'VIP%' with required_vip_level=0.
-- Also sync item expiry to users.vip_until instead of a fixed 30-day window.

CREATE OR REPLACE FUNCTION public.provision_user_assets(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_vip_level INT;
    v_vip_until TIMESTAMPTZ;
    v_wealth BIGINT;
    v_charm BIGINT;
    v_asset_expires TIMESTAMPTZ;
    r RECORD;
BEGIN
    SELECT vip_level, vip_until, wealth_value, charm_value
    INTO v_vip_level, v_vip_until, v_wealth, v_charm
    FROM public.users
    WHERE id = p_user_id;

    v_asset_expires := COALESCE(
        CASE WHEN v_vip_until > NOW() THEN v_vip_until END,
        NOW() + INTERVAL '30 days'
    );

    -- A. Provision VIP Assets (source_type vip OR VIP-named shop items)
    FOR r IN
        WITH vip_shop_items AS (
            SELECT
                si.id,
                CASE
                    WHEN si.required_vip_level > 0 THEN si.required_vip_level
                    WHEN si.name ~* 'VIP\s*(\d+)' THEN (regexp_match(si.name, 'VIP\s*(\d+)', 'i'))[1]::INT
                    ELSE 0
                END AS effective_vip_level
            FROM public.shop_items si
            WHERE si.is_active = TRUE
              AND (
                  si.source_type = 'vip'
                  OR si.name ILIKE 'VIP%'
              )
        )
        SELECT id
        FROM vip_shop_items
        WHERE effective_vip_level > 0
          AND effective_vip_level <= v_vip_level
    LOOP
        INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
        VALUES (p_user_id, r.id, 'vip_reward', v_asset_expires)
        ON CONFLICT (user_id, item_id) DO UPDATE SET
            source = 'vip_reward',
            expires_at = CASE
                WHEN user_inventory.expires_at IS NULL OR user_inventory.expires_at < NOW()
                THEN EXCLUDED.expires_at
                ELSE GREATEST(user_inventory.expires_at, EXCLUDED.expires_at)
            END;
    END LOOP;

    -- B. Provision Achievement Medals (Permanent)
    FOR r IN
        SELECT id FROM public.shop_items
        WHERE source_type = 'medal' AND required_wealth_value > 0 AND required_wealth_value <= v_wealth
    LOOP
        INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
        VALUES (p_user_id, r.id, 'achievement', '9999-12-31'::TIMESTAMPTZ)
        ON CONFLICT (user_id, item_id) DO NOTHING;
    END LOOP;

    FOR r IN
        SELECT id FROM public.shop_items
        WHERE source_type = 'medal' AND required_charm_value > 0 AND required_charm_value <= v_charm
    LOOP
        INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
        VALUES (p_user_id, r.id, 'achievement', '9999-12-31'::TIMESTAMPTZ)
        ON CONFLICT (user_id, item_id) DO NOTHING;
    END LOOP;
END;
$function$;

-- Repair existing rows: active VIP members with stale inventory expiry
UPDATE public.user_inventory ui
SET expires_at = u.vip_until,
    source = CASE WHEN ui.source = 'purchase' THEN 'vip_reward' ELSE ui.source END
FROM public.users u,
     public.shop_items si
WHERE ui.user_id = u.id
  AND si.id = ui.item_id
  AND u.vip_level > 0
  AND u.vip_until IS NOT NULL
  AND u.vip_until > NOW()
  AND ui.expires_at < u.vip_until
  AND (
      (si.source_type = 'vip' AND si.required_vip_level > 0 AND si.required_vip_level <= u.vip_level)
      OR (
          si.name ILIKE 'VIP%'
          AND COALESCE(
              NULLIF(si.required_vip_level, 0),
              (regexp_match(si.name, 'VIP\s*(\d+)', 'i'))[1]::INT,
              0
          ) > 0
          AND COALESCE(
              NULLIF(si.required_vip_level, 0),
              (regexp_match(si.name, 'VIP\s*(\d+)', 'i'))[1]::INT,
              0
          ) <= u.vip_level
      )
  );

-- Re-provision all currently active VIP users (includes short_id 1010 / almohsin dev)
DO $$
DECLARE
    u RECORD;
BEGIN
    FOR u IN
        SELECT id
        FROM public.users
        WHERE vip_level > 0
          AND vip_until IS NOT NULL
          AND vip_until > NOW()
    LOOP
        PERFORM public.provision_user_assets(u.id);
    END LOOP;
END;
$$;
