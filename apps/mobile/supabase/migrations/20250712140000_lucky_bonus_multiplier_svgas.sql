-- Lucky / Lucky Pro bonus multiplier SVGA banners (room float).
-- Admin can enable/disable/update/remove rows; Flutter loads enabled set.

CREATE TABLE IF NOT EXISTS public.lucky_bonus_multiplier_svgas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  multiplier integer NOT NULL,
  label text NOT NULL DEFAULT '',
  svga_url text NOT NULL,
  is_enabled boolean NOT NULL DEFAULT true,
  applies_to text NOT NULL DEFAULT 'both'
    CHECK (applies_to IN ('lucky', 'lucky_pro', 'both')),
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lucky_bonus_multiplier_svgas_multiplier_unique UNIQUE (multiplier)
);

CREATE INDEX IF NOT EXISTS idx_lucky_bonus_multiplier_svgas_enabled
  ON public.lucky_bonus_multiplier_svgas (is_enabled, multiplier);

ALTER TABLE public.lucky_bonus_multiplier_svgas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read enabled lucky bonus svgas"
  ON public.lucky_bonus_multiplier_svgas;
CREATE POLICY "Public read enabled lucky bonus svgas"
  ON public.lucky_bonus_multiplier_svgas
  FOR SELECT
  TO anon, authenticated
  USING (is_enabled = true);

GRANT SELECT ON public.lucky_bonus_multiplier_svgas TO anon, authenticated;
GRANT ALL ON public.lucky_bonus_multiplier_svgas TO service_role;
