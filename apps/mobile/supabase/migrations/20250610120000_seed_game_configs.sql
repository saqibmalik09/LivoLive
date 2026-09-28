-- Seed / refresh all sk-live-game configs (idempotent).
-- game_url is set by setup_games.js via GAME_BASE_URL env (Railway / Vercel / local).

INSERT INTO public.game_configs (
  slug, name, is_active, game_url, icon_url, sort_order, min_bet, max_bet, config_data
) VALUES
(
  'car_roulette',
  'Car Roulette',
  true,
  'https://sk-live-games.vercel.app/',
  'https://sk-live-games.vercel.app/splash_logo.png',
  1,
  10,
  1000000,
  '{
    "options": [
      {"id": "bugatti"}, {"id": "bentley"}, {"id": "ferrari"}, {"id": "lamborghini"},
      {"id": "porsche"}, {"id": "landrover"}, {"id": "jaguar"}, {"id": "mercedes"},
      {"id": "vw"}, {"id": "bmw"}
    ],
    "multipliers": {
      "bugatti": 100, "bentley": 88, "ferrari": 66, "lamborghini": 50,
      "porsche": 30, "landrover": 20, "jaguar": 18, "mercedes": 8,
      "vw": 5, "bmw": 2
    }
  }'::jsonb
),
(
  'football_roulette',
  'Football Roulette',
  true,
  'https://sk-live-games.vercel.app/football-phaser',
  'https://sk-live-games.vercel.app/game-icons/football_roulette_icon.png',
  2,
  10,
  1000000,
  '{
    "options": [
      {"id": "man_united"}, {"id": "al_nassr"}, {"id": "bayern"}, {"id": "porto"},
      {"id": "juventus"}, {"id": "man_city"}, {"id": "psg"}, {"id": "real_madrid"},
      {"id": "soccer_club"}, {"id": "aldenaire"}
    ],
    "multipliers": {
      "man_united": 100, "al_nassr": 88, "bayern": 66, "porto": 50,
      "juventus": 30, "man_city": 20, "psg": 18, "real_madrid": 8,
      "soccer_club": 5, "aldenaire": 2
    }
  }'::jsonb
),
(
  'pizza_express',
  'Pizza Express',
  true,
  'https://sk-live-games.vercel.app/pizza',
  'https://sk-live-games.vercel.app/pizza/pizza.png',
  3,
  10,
  1000000,
  '{
    "options": [
      {"id": "pizza"}, {"id": "burger"}, {"id": "fries"}, {"id": "icecream"},
      {"id": "water"}, {"id": "soda"}, {"id": "donut"}, {"id": "taco"}
    ],
    "multipliers": {
      "pizza": 10, "burger": 15, "fries": 25, "icecream": 45,
      "water": 5, "soda": 5, "donut": 5, "taco": 5
    }
  }'::jsonb
),
(
  'greedy_king',
  'Greedy King',
  true,
  'https://sk-live-games.vercel.app/greedy',
  'https://sk-live-games.vercel.app/pizza/pizza.png',
  4,
  10,
  1000000,
  '{
    "options": [
      {"id": "pizza"}, {"id": "burger"}, {"id": "fries"}, {"id": "icecream"},
      {"id": "water"}, {"id": "soda"}, {"id": "donut"}, {"id": "taco"}
    ],
    "multipliers": {
      "pizza": 10, "burger": 15, "fries": 25, "icecream": 45,
      "water": 5, "soda": 5, "donut": 5, "taco": 5
    }
  }'::jsonb
)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  is_active = EXCLUDED.is_active,
  game_url = EXCLUDED.game_url,
  icon_url = EXCLUDED.icon_url,
  sort_order = EXCLUDED.sort_order,
  min_bet = EXCLUDED.min_bet,
  max_bet = EXCLUDED.max_bet,
  config_data = EXCLUDED.config_data;

INSERT INTO public.system_settings (key, value)
VALUES ('game_control_mode', 'random')
ON CONFLICT (key) DO NOTHING;
