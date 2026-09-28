-- Lucky 777: 3-option board (watermelon ×2, seventy_seven ×8, plum ×2).
-- Wheel layout is client-side (8 slices); server picks among the 3 option ids.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'game_configs_slug_key'
  ) THEN
    ALTER TABLE public.game_configs ADD CONSTRAINT game_configs_slug_key UNIQUE (slug);
  END IF;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

INSERT INTO public.game_configs (
  slug, name, is_active, min_bet, max_bet,
  betting_duration, spinning_duration, result_duration,
  config_data, game_url, icon_url, sort_order
)
VALUES (
  'lucky_777',
  'Lucky 777',
  true,
  1000,
  10000000,
  interval '20 seconds',
  interval '10 seconds',
  interval '5 seconds',
  jsonb_build_object(
    'options', jsonb_build_array(
      jsonb_build_object('id', 'watermelon'),
      jsonb_build_object('id', 'seventy_seven'),
      jsonb_build_object('id', 'plum')
    ),
    'multipliers', jsonb_build_object(
      'watermelon', 2,
      'seventy_seven', 8,
      'plum', 2
    )
  ),
  'https://sk-live-games.vercel.app/777',
  'https://sk-live-games.vercel.app/game-icons/lucky_777_icon.webp',
  7
)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  is_active = true,
  min_bet = EXCLUDED.min_bet,
  max_bet = EXCLUDED.max_bet,
  betting_duration = EXCLUDED.betting_duration,
  spinning_duration = EXCLUDED.spinning_duration,
  result_duration = EXCLUDED.result_duration,
  config_data = EXCLUDED.config_data,
  game_url = EXCLUDED.game_url,
  icon_url = EXCLUDED.icon_url,
  sort_order = EXCLUDED.sort_order;

INSERT INTO public.game_rounds (game_id, status, betting_ends_at, spinning_ends_at, round_ends_at)
SELECT
  c.id,
  'betting',
  now() + c.betting_duration,
  now() + c.betting_duration + c.spinning_duration,
  now() + c.betting_duration + c.spinning_duration + c.result_duration
FROM public.game_configs c
WHERE c.slug = 'lucky_777'
  AND NOT EXISTS (
    SELECT 1 FROM public.game_rounds r
    WHERE r.game_id = c.id AND r.status IN ('betting', 'spinning', 'result')
  );
