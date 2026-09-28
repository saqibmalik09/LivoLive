-- Home Hot tab: games icon row between ranking podium and hot cards.
-- Admin-curated subset/order; falls back to game_configs icon/name/url.

CREATE TABLE IF NOT EXISTS public.home_games_row_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_slug text NOT NULL,
  title text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT home_games_row_items_game_slug_key UNIQUE (game_slug)
);

CREATE INDEX IF NOT EXISTS home_games_row_items_active_order_idx
  ON public.home_games_row_items (is_active, sort_order ASC);

COMMENT ON TABLE public.home_games_row_items IS
  'Home Hot tab horizontal games icons (between podium and hot cards).';

-- Seed from currently active games (idempotent).
INSERT INTO public.home_games_row_items (game_slug, title, image_url, sort_order, is_active)
SELECT
  gc.slug,
  COALESCE(gc.name, gc.slug),
  COALESCE(gc.icon_url, ''),
  COALESCE(gc.sort_order, 0),
  true
FROM public.game_configs gc
WHERE COALESCE(gc.is_active, false) = true
  AND COALESCE(gc.slug, '') <> ''
ON CONFLICT (game_slug) DO NOTHING;

ALTER TABLE public.home_games_row_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read home games row items" ON public.home_games_row_items;
CREATE POLICY "Public read home games row items"
  ON public.home_games_row_items
  FOR SELECT
  TO public
  USING (true);

REVOKE ALL ON TABLE public.home_games_row_items FROM PUBLIC;
GRANT SELECT ON TABLE public.home_games_row_items TO anon, authenticated;
GRANT ALL ON TABLE public.home_games_row_items TO service_role;
