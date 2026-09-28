-- Room games sheet categories (native H5 + Tulasi in game_configs).

CREATE TABLE IF NOT EXISTS public.room_game_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS room_game_categories_name_uidx
  ON public.room_game_categories (lower(name));

CREATE INDEX IF NOT EXISTS room_game_categories_sort_idx
  ON public.room_game_categories (is_active, sort_order);

ALTER TABLE public.room_game_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "room_game_categories_select_authenticated"
  ON public.room_game_categories;
CREATE POLICY "room_game_categories_select_authenticated"
  ON public.room_game_categories
  FOR SELECT
  TO authenticated
  USING (is_active = true);

GRANT SELECT ON TABLE public.room_game_categories TO authenticated;

ALTER TABLE public.game_configs
  ADD COLUMN IF NOT EXISTS category_id uuid
  REFERENCES public.room_game_categories(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS game_configs_category_idx
  ON public.game_configs (category_id);

-- Seed default categories (idempotent)
INSERT INTO public.room_game_categories (name, sort_order, is_active)
SELECT v.name, v.sort_order, true
FROM (VALUES
  ('Hot', 10),
  ('SK Live Games', 20),
  ('Casino', 30),
  ('Arcade', 40),
  ('More Games', 100)
) AS v(name, sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM public.room_game_categories c WHERE lower(c.name) = lower(v.name)
);

-- Native (non-Tulasi) → SK Live Games
UPDATE public.game_configs g
SET category_id = c.id
FROM public.room_game_categories c
WHERE c.name = 'SK Live Games'
  AND g.category_id IS NULL
  AND coalesce(g.config_data->>'provider', '') <> 'tulasi';

-- Tulasi Hot
UPDATE public.game_configs g
SET category_id = c.id
FROM public.room_game_categories c
WHERE c.name = 'Hot'
  AND g.category_id IS NULL
  AND g.config_data->>'provider' = 'tulasi'
  AND g.slug IN ('flightChess', 'fruitLoops', 'kingdoms', 'kingdoms2');

-- Tulasi Casino
UPDATE public.game_configs g
SET category_id = c.id
FROM public.room_game_categories c
WHERE c.name = 'Casino'
  AND g.category_id IS NULL
  AND g.config_data->>'provider' = 'tulasi'
  AND g.slug IN ('roulette', 'dragonTigerBattle', 'lucky77', 'lucky99');

-- Tulasi Arcade
UPDATE public.game_configs g
SET category_id = c.id
FROM public.room_game_categories c
WHERE c.name = 'Arcade'
  AND g.category_id IS NULL
  AND g.config_data->>'provider' = 'tulasi'
  AND (
    g.slug IN ('greedy', 'fruitMachine', 'whackAMole')
    OR g.slug ILIKE 'slots%'
  );

-- Remaining Tulasi → More Games
UPDATE public.game_configs g
SET category_id = c.id
FROM public.room_game_categories c
WHERE c.name = 'More Games'
  AND g.category_id IS NULL
  AND g.config_data->>'provider' = 'tulasi';
