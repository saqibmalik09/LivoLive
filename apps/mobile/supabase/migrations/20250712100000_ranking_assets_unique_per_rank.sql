-- Ensure each podium/ranking seat has its own asset row (no shared frame).
CREATE UNIQUE INDEX IF NOT EXISTS ranking_assets_category_type_rank_uidx
  ON public.ranking_assets (category, ranking_type, rank_position);

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
