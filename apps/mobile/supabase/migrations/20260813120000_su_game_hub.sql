-- SU (Game tab) hub: admin categories + which games appear in each.
-- Left rail = categories; right grid = that category's games.

CREATE TABLE IF NOT EXISTS public.su_game_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS su_game_categories_active_order_idx
  ON public.su_game_categories (is_active, sort_order ASC);

COMMENT ON TABLE public.su_game_categories IS
  'SU / Game tab left-side categories.';

CREATE TABLE IF NOT EXISTS public.su_game_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES public.su_game_categories(id) ON DELETE CASCADE,
  kind text NOT NULL DEFAULT 'h5',
  game_slug text,
  title text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT su_game_items_kind_check CHECK (kind IN ('h5', 'rupee')),
  CONSTRAINT su_game_items_h5_slug_check CHECK (
    (kind = 'h5' AND COALESCE(game_slug, '') <> '')
    OR (kind = 'rupee')
  )
);

CREATE INDEX IF NOT EXISTS su_game_items_category_active_order_idx
  ON public.su_game_items (category_id, is_active, sort_order ASC);

CREATE UNIQUE INDEX IF NOT EXISTS su_game_items_category_h5_slug_uidx
  ON public.su_game_items (category_id, game_slug)
  WHERE kind = 'h5' AND game_slug IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS su_game_items_category_rupee_uidx
  ON public.su_game_items (category_id)
  WHERE kind = 'rupee';

COMMENT ON TABLE public.su_game_items IS
  'SU / Game tab icons per category. kind=h5 uses game_configs; kind=rupee opens Lucky Offer.';

INSERT INTO public.su_game_categories (name, sort_order, is_active)
SELECT 'Hot', 0, true
WHERE NOT EXISTS (SELECT 1 FROM public.su_game_categories);

INSERT INTO public.su_game_items (
  category_id, kind, game_slug, title, image_url, sort_order, is_active
)
SELECT
  c.id,
  'h5',
  gc.slug,
  COALESCE(gc.name, gc.slug),
  COALESCE(gc.icon_url, ''),
  COALESCE(gc.sort_order, 0),
  true
FROM public.su_game_categories c
CROSS JOIN public.game_configs gc
WHERE c.name = 'Hot'
  AND COALESCE(gc.slug, '') <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM public.su_game_items i
    WHERE i.category_id = c.id
      AND i.kind = 'h5'
      AND i.game_slug = gc.slug
  );

INSERT INTO public.su_game_items (
  category_id, kind, game_slug, title, image_url, sort_order, is_active
)
SELECT c.id, 'rupee', NULL, 'Lucky Offer', '', 1000, true
FROM public.su_game_categories c
WHERE c.name = 'Hot'
  AND NOT EXISTS (
    SELECT 1
    FROM public.su_game_items i
    WHERE i.category_id = c.id AND i.kind = 'rupee'
  );

ALTER TABLE public.su_game_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.su_game_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read su game categories" ON public.su_game_categories;
CREATE POLICY "Public read su game categories"
  ON public.su_game_categories
  FOR SELECT
  TO public
  USING (true);

DROP POLICY IF EXISTS "Public read su game items" ON public.su_game_items;
CREATE POLICY "Public read su game items"
  ON public.su_game_items
  FOR SELECT
  TO public
  USING (true);

REVOKE ALL ON TABLE public.su_game_categories FROM PUBLIC;
REVOKE ALL ON TABLE public.su_game_items FROM PUBLIC;
GRANT SELECT ON TABLE public.su_game_categories TO anon, authenticated;
GRANT SELECT ON TABLE public.su_game_items TO anon, authenticated;
GRANT ALL ON TABLE public.su_game_categories TO service_role;
GRANT ALL ON TABLE public.su_game_items TO service_role;
