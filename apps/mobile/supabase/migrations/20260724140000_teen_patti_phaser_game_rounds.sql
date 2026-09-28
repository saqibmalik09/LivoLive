-- Teen Patti → independent 3-party betting on game_rounds (wolf / lion / fish),
-- same engine as Fruit Party / Greedy King. Seat-join teen_patti_rounds engine disabled.

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
  'teen_patti',
  'Teen Patti',
  true,
  200,
  50000,
  interval '30 seconds',
  interval '8 seconds',
  interval '5 seconds',
  jsonb_build_object(
    'options', jsonb_build_array(
      jsonb_build_object('id', 'wolf'),
      jsonb_build_object('id', 'lion'),
      jsonb_build_object('id', 'fish')
    ),
    'multipliers', jsonb_build_object(
      'wolf', 3,
      'lion', 3,
      'fish', 3
    )
  ),
  'https://sk-live-games.vercel.app/teen-patti-phaser',
  'https://sk-live-games.vercel.app/game-icons/teen_patti_icon.png',
  2
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

-- Stop seat-lobby advance so only game_rounds drives Teen Patti.
CREATE OR REPLACE FUNCTION public.teen_patti_advance_rounds()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- No-op: Teen Patti now uses public.game_rounds + place_game_bet.
  RETURN;
END;
$$;

-- Finish any stuck seat-lobby rounds.
UPDATE public.teen_patti_rounds
SET status = 'finished',
    round_ends_at = COALESCE(round_ends_at, now())
WHERE status IN ('betting', 'showdown')
  AND room_id IS NULL;

INSERT INTO public.game_rounds (game_id, status, betting_ends_at, spinning_ends_at, round_ends_at)
SELECT
  c.id,
  'betting',
  now() + c.betting_duration,
  now() + c.betting_duration + c.spinning_duration,
  now() + c.betting_duration + c.spinning_duration + c.result_duration
FROM public.game_configs c
WHERE c.slug = 'teen_patti'
  AND NOT EXISTS (
    SELECT 1 FROM public.game_rounds r
    WHERE r.game_id = c.id AND r.status IN ('betting', 'spinning', 'result')
  );
