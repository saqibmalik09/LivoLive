-- Room live right-bottom floating promo rail (square event + game icons).
-- Admin-managed images; seeded from existing party_events + game_configs.

CREATE TABLE IF NOT EXISTS public.room_side_float_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL,
  title text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  party_event_id uuid REFERENCES public.party_events (id) ON DELETE SET NULL,
  game_slug text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT room_side_float_items_kind_check CHECK (kind IN ('event', 'game'))
);

CREATE INDEX IF NOT EXISTS room_side_float_items_kind_active_idx
  ON public.room_side_float_items (kind, is_active, sort_order ASC);

ALTER TABLE public.room_side_float_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read room side float items" ON public.room_side_float_items;
CREATE POLICY "Public read room side float items"
  ON public.room_side_float_items
  FOR SELECT
  TO public
  USING (true);

-- Seed events (skip if already seeded)
INSERT INTO public.room_side_float_items (
  kind, title, image_url, party_event_id, sort_order, is_active
)
SELECT
  'event',
  COALESCE(NULLIF(trim(pe.title), ''), 'Event'),
  COALESCE(pe.banner_url, ''),
  pe.id,
  ROW_NUMBER() OVER (ORDER BY pe.priority DESC NULLS LAST, pe.created_at DESC) - 1,
  true
FROM public.party_events pe
WHERE pe.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM public.room_side_float_items r
    WHERE r.kind = 'event' AND r.party_event_id = pe.id
  );

-- Seed games (skip if already seeded)
INSERT INTO public.room_side_float_items (
  kind, title, image_url, game_slug, sort_order, is_active
)
SELECT
  'game',
  COALESCE(NULLIF(trim(gc.name), ''), gc.slug),
  COALESCE(gc.icon_url, ''),
  gc.slug,
  COALESCE(gc.sort_order, 0),
  true
FROM public.game_configs gc
WHERE gc.is_active = true
  AND COALESCE(gc.icon_url, '') <> ''
  AND NOT EXISTS (
    SELECT 1 FROM public.room_side_float_items r
    WHERE r.kind = 'game' AND r.game_slug = gc.slug
  );
