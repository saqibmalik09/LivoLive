-- Agency starter (LV0) + LV1 nameplate badges.
-- Assets live in storage shop_assets/agency-levels/

INSERT INTO public.agency_level_configs (level, min_exp, tier_name, badge_url)
VALUES (
  0,
  0,
  'Starter Agency',
  'https://pbobnvkscssgfpynmdhl.supabase.co/storage/v1/object/public/shop_assets/agency-levels/agencylv0.png'
)
ON CONFLICT (level) DO UPDATE SET
  min_exp = EXCLUDED.min_exp,
  tier_name = EXCLUDED.tier_name,
  badge_url = EXCLUDED.badge_url;

-- LV1 starts after 0 so new agencies (0 exp) keep the starter nameplate.
UPDATE public.agency_level_configs
SET
  min_exp = CASE WHEN min_exp = 0 THEN 1 ELSE min_exp END,
  badge_url = 'https://pbobnvkscssgfpynmdhl.supabase.co/storage/v1/object/public/shop_assets/agency-levels/agencylv1.png',
  tier_name = COALESCE(NULLIF(tier_name, ''), 'Bronze Agency')
WHERE level = 1;

-- Temporarily reuse LV1 nameplate art for every level except starter (0).
UPDATE public.agency_level_configs
SET badge_url = 'https://pbobnvkscssgfpynmdhl.supabase.co/storage/v1/object/public/shop_assets/agency-levels/agencylv1.png'
WHERE level <> 0;
