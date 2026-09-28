-- Allow Fruit Party 1M / 10M chips (was capped at 500K).
UPDATE public.game_configs
SET max_bet = 10000000
WHERE slug = 'fruit_party'
  AND max_bet < 10000000;
