-- BD Gift Pack assets per level (admin-configurable shop items / uploads)

CREATE TABLE IF NOT EXISTS public.bd_gift_pack_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level int NOT NULL REFERENCES public.bd_level_configs(level) ON DELETE CASCADE,
  feature_key text NOT NULL CHECK (
    feature_key IN ('bd_frame', 'svip', 'country_bd_badge', 'custom')
  ),
  shop_item_id uuid REFERENCES public.shop_items(id) ON DELETE SET NULL,
  image_url text,
  label text,
  duration_days int NOT NULL DEFAULT 30,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (level, feature_key)
);

CREATE INDEX IF NOT EXISTS idx_bd_gift_pack_assets_level
  ON public.bd_gift_pack_assets (level);

ALTER TABLE public.bd_gift_pack_assets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read bd gift packs" ON public.bd_gift_pack_assets;
CREATE POLICY "Public read bd gift packs"
  ON public.bd_gift_pack_assets FOR SELECT TO public USING (true);

-- Seed empty slots for LV1–LV10 (3 slots each)
INSERT INTO public.bd_gift_pack_assets (level, feature_key, label, duration_days, sort_order)
SELECT v.level, v.feature_key, v.label, 30, v.sort_order
FROM (
  VALUES
    (1, 'bd_frame', 'BD LV1 Frame', 0),
    (1, 'svip', 'SVIP1', 1),
    (1, 'country_bd_badge', 'CountryBD', 2),
    (2, 'bd_frame', 'BD LV2 Frame', 0),
    (2, 'svip', 'SVIP1', 1),
    (2, 'country_bd_badge', 'CountryBD', 2),
    (3, 'bd_frame', 'BD LV3 Frame', 0),
    (3, 'svip', 'SVIP1', 1),
    (3, 'country_bd_badge', 'CountryBD', 2),
    (4, 'bd_frame', 'BD LV4 Frame', 0),
    (4, 'svip', 'SVIP1', 1),
    (4, 'country_bd_badge', 'CountryBD', 2),
    (5, 'bd_frame', 'BD LV5 Frame', 0),
    (5, 'svip', 'SVIP1', 1),
    (5, 'country_bd_badge', 'CountryBD', 2),
    (6, 'bd_frame', 'BD LV6 Frame', 0),
    (6, 'svip', 'SVIP1', 1),
    (6, 'country_bd_badge', 'CountryBD', 2),
    (7, 'bd_frame', 'BD LV7 Frame', 0),
    (7, 'svip', 'SVIP1', 1),
    (7, 'country_bd_badge', 'CountryBD', 2),
    (8, 'bd_frame', 'BD LV8 Frame', 0),
    (8, 'svip', 'SVIP1', 1),
    (8, 'country_bd_badge', 'CountryBD', 2),
    (9, 'bd_frame', 'BD LV9 Frame', 0),
    (9, 'svip', 'SVIP1', 1),
    (9, 'country_bd_badge', 'CountryBD', 2),
    (10, 'bd_frame', 'BD LV10 Frame', 0),
    (10, 'svip', 'SVIP1', 1),
    (10, 'country_bd_badge', 'CountryBD', 2)
) AS v(level, feature_key, label, sort_order)
ON CONFLICT (level, feature_key) DO NOTHING;

-- Level badge image on bd_level_configs (already has badge_url)
ALTER TABLE public.bd_level_configs
  ADD COLUMN IF NOT EXISTS badge_url text;

CREATE OR REPLACE FUNCTION public.get_bd_gift_packs()
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level), '[]'::json)
  FROM (
    SELECT
      l.level,
      l.badge_url,
      l.agency_target_usd,
      (
        SELECT COALESCE(json_agg(row_to_json(a) ORDER BY a.sort_order), '[]'::json)
        FROM (
          SELECT
            g.feature_key,
            g.label,
            g.duration_days,
            g.sort_order,
            g.image_url,
            g.shop_item_id,
            si.name AS shop_item_name,
            COALESCE(g.image_url, si.image_url) AS display_image_url
          FROM public.bd_gift_pack_assets g
          LEFT JOIN public.shop_items si ON si.id = g.shop_item_id
          WHERE g.level = l.level
        ) a
      ) AS rewards
    FROM public.bd_level_configs l
    WHERE l.is_active AND l.level > 0
  ) t;
$$;

GRANT EXECUTE ON FUNCTION public.get_bd_gift_packs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_bd_gift_packs() TO anon;

-- Include gift packs in get_my_bd_center response
CREATE OR REPLACE FUNCTION public.get_my_bd_center(p_period_yyyy_mm text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff public.business_staff%ROWTYPE;
  v_period text := COALESCE(p_period_yyyy_mm, to_char(current_date, 'YYYY-MM'));
  v_stats public.bd_staff_monthly_stats%ROWTYPE;
  v_settings public.bd_center_settings%ROWTYPE;
  v_next public.bd_level_configs%ROWTYPE;
  v_agencies json;
  v_gift_packs json;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_staff FROM public.business_staff
  WHERE user_id = v_uid AND is_active = true
  ORDER BY created_at DESC LIMIT 1;

  IF v_staff.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No staff role');
  END IF;

  IF public.normalize_staff_role(v_staff.role) = 'bd' THEN
    PERFORM public.refresh_bd_monthly_stats(v_staff.id, v_period);
  END IF;

  SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
  WHERE staff_id = v_staff.id AND period_yyyy_mm = v_period;

  SELECT * INTO v_settings FROM public.bd_center_settings WHERE id = 1;

  SELECT * INTO v_next FROM public.bd_level_configs
  WHERE is_active AND level > COALESCE(v_stats.achieved_level, 0)
  ORDER BY level ASC LIMIT 1;

  SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) INTO v_agencies
  FROM (
    SELECT id, name, agency_code, is_active, owner_id, created_at
    FROM public.agencies
    WHERE sponsor_staff_id = v_staff.id AND is_active = true
      AND owner_id IS DISTINCT FROM v_staff.user_id
    ORDER BY created_at DESC
  ) a;

  v_gift_packs := public.get_bd_gift_packs();

  RETURN json_build_object(
    'success', true,
    'staff', json_build_object(
      'id', v_staff.id,
      'role', public.normalize_staff_role(v_staff.role),
      'staff_code', v_staff.staff_code
    ),
    'period', v_period,
    'settlement_day', COALESCE(v_settings.settlement_day_of_month, 15),
    'timezone', COALESCE(v_settings.timezone, 'UTC+3'),
    'stats', CASE WHEN v_stats.id IS NULL THEN NULL ELSE json_build_object(
      'agency_target_usd', v_stats.agency_target_usd,
      'achieved_level', v_stats.achieved_level,
      'est_basic_usd', v_stats.est_basic_usd,
      'est_commission_usd', v_stats.est_commission_usd,
      'est_new_bd_usd', v_stats.est_new_bd_usd,
      'est_total_usd', v_stats.est_total_usd,
      'new_agencies', v_stats.new_agencies,
      'in_new_bd_window', v_stats.in_new_bd_window,
      'work_days', v_stats.work_days,
      'work_hours', v_stats.work_hours
    ) END,
    'next_level', CASE WHEN v_next.level IS NULL THEN NULL ELSE json_build_object(
      'level', v_next.level,
      'agency_target_usd', v_next.agency_target_usd,
      'remaining_usd', GREATEST(v_next.agency_target_usd - COALESCE(v_stats.agency_target_usd, 0), 0)
    ) END,
    'agencies', v_agencies,
    'levels', (SELECT COALESCE(json_agg(row_to_json(l) ORDER BY l.level), '[]'::json) FROM public.bd_level_configs l WHERE l.is_active),
    'gift_packs', v_gift_packs
  );
END;
$function$;
