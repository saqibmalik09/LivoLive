-- Agency level configs + profile frame assets (hero / honor / charm) + shop rewards.

CREATE TABLE IF NOT EXISTS public.agency_level_configs (
  level integer PRIMARY KEY,
  min_exp bigint NOT NULL DEFAULT 0,
  tier_name text NOT NULL DEFAULT 'Bronze Agency',
  badge_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.agency_level_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level integer NOT NULL REFERENCES public.agency_level_configs(level) ON DELETE CASCADE,
  feature_key text NOT NULL CHECK (
    feature_key IN (
      'hero_frame',
      'honor_frame',
      'charm_frame',
      'frame',
      'bubble',
      'card_background',
      'entrance'
    )
  ),
  image_url text,
  shop_item_id uuid REFERENCES public.shop_items(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (level, feature_key)
);

CREATE INDEX IF NOT EXISTS idx_agency_level_assets_level
  ON public.agency_level_assets (level);

ALTER TABLE public.agency_level_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agency_level_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read agency level configs" ON public.agency_level_configs;
CREATE POLICY "Public read agency level configs"
  ON public.agency_level_configs FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Public read agency level assets" ON public.agency_level_assets;
CREATE POLICY "Public read agency level assets"
  ON public.agency_level_assets FOR SELECT TO public USING (true);

INSERT INTO public.agency_level_configs (level, min_exp, tier_name)
SELECT v.level, v.min_exp, v.tier_name
FROM (
  VALUES
    (1, 0::bigint, 'Bronze Agency'),
    (2, 2500000000::bigint, 'Bronze Agency'),
    (3, 5000000000::bigint, 'Silver Agency'),
    (4, 7500000000::bigint, 'Silver Agency'),
    (5, 10000000000::bigint, 'Gold Agency'),
    (6, 12500000000::bigint, 'Gold Agency'),
    (7, 15000000000::bigint, 'Diamond Agency'),
    (8, 17500000000::bigint, 'Diamond Agency'),
    (9, 20000000000::bigint, 'Diamond Agency'),
    (10, 25000000000::bigint, 'Diamond Agency')
) AS v(level, min_exp, tier_name)
ON CONFLICT (level) DO NOTHING;
