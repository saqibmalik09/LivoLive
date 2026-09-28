-- Party (Home) screen background: top + bottom images (admin-managed), middle is app gradient.

CREATE TABLE IF NOT EXISTS public.party_screen_config (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  top_image_url text NOT NULL DEFAULT '',
  bottom_image_url text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.party_screen_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read party screen config" ON public.party_screen_config;
CREATE POLICY "Public read party screen config"
  ON public.party_screen_config
  FOR SELECT
  TO public
  USING (true);

INSERT INTO public.party_screen_config (id, top_image_url, bottom_image_url)
VALUES (1, '', '')
ON CONFLICT (id) DO NOTHING;
