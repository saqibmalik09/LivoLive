-- Hot tab ranking podium backgrounds (Room / Agency / Charm / Wealth).

CREATE TABLE IF NOT EXISTS public.home_ranking_podium_config (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  room_bg_url text NOT NULL DEFAULT '',
  agency_bg_url text NOT NULL DEFAULT '',
  charm_bg_url text NOT NULL DEFAULT '',
  wealth_bg_url text NOT NULL DEFAULT '',
  slide_interval_ms int NOT NULL DEFAULT 5000,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.home_ranking_podium_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read home ranking podium config" ON public.home_ranking_podium_config;
CREATE POLICY "Public read home ranking podium config"
  ON public.home_ranking_podium_config
  FOR SELECT
  TO public
  USING (true);

INSERT INTO public.home_ranking_podium_config (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;
