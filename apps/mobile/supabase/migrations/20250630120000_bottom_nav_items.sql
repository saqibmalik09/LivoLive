-- Bottom navigation items (labels + icons managed from admin panel)

CREATE TABLE IF NOT EXISTS public.bottom_nav_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nav_key text UNIQUE NOT NULL CHECK (nav_key IN ('home', 'party', 'message', 'my')),
  label text NOT NULL,
  icon_url text NOT NULL DEFAULT '',
  active_icon_url text,
  focus_overlay_url text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bottom_nav_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read active bottom nav items" ON public.bottom_nav_items;
CREATE POLICY "Public read active bottom nav items"
  ON public.bottom_nav_items
  FOR SELECT
  TO public
  USING (is_active = true);

INSERT INTO public.bottom_nav_items (nav_key, label, icon_url, sort_order, is_active)
VALUES
  ('home', 'Home', '', 0, true),
  ('party', 'Party', '', 1, true),
  ('message', 'Message', '', 2, true),
  ('my', 'My', '', 3, true)
ON CONFLICT (nav_key) DO UPDATE SET
  label = EXCLUDED.label,
  sort_order = EXCLUDED.sort_order;

-- Ensure app_assets bucket exists for bottom-nav icon uploads
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'app_assets',
  'app_assets',
  true,
  5242880,
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public read app_assets" ON storage.objects;
CREATE POLICY "Public read app_assets"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'app_assets');
