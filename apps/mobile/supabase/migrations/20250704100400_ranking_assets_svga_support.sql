-- Podium frame SVGA support + ensure daily Podium rows + public read for app.

ALTER TABLE public.ranking_assets
  ADD COLUMN IF NOT EXISTS frame_media_type text NOT NULL DEFAULT 'image';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ranking_assets_frame_media_type_check'
  ) THEN
    ALTER TABLE public.ranking_assets
      ADD CONSTRAINT ranking_assets_frame_media_type_check
      CHECK (frame_media_type IN ('image', 'svga'));
  END IF;
END $$;

INSERT INTO public.ranking_assets (
  category,
  rank_position,
  ranking_type,
  frame_url,
  badge_url,
  frame_media_type
)
SELECT v.category, v.rank_position, v.ranking_type, '', '', 'image'
FROM (
  VALUES
    ('Podium', 1, 'daily'),
    ('Podium', 2, 'daily'),
    ('Podium', 3, 'daily')
) AS v(category, rank_position, ranking_type)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.ranking_assets ra
  WHERE ra.category = v.category
    AND ra.rank_position = v.rank_position
    AND ra.ranking_type = v.ranking_type
);

ALTER TABLE public.ranking_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read ranking assets" ON public.ranking_assets;
CREATE POLICY "Public read ranking assets"
  ON public.ranking_assets
  FOR SELECT
  TO public
  USING (true);
