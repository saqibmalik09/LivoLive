-- Per-slide home podium frames (optional overrides of shared Podium).
-- PodiumRoom / PodiumAgency / PodiumCharm / PodiumWealth × TOP 1–3.

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
    ('Podium', 3, 'daily'),
    ('PodiumRoom', 1, 'daily'),
    ('PodiumRoom', 2, 'daily'),
    ('PodiumRoom', 3, 'daily'),
    ('PodiumAgency', 1, 'daily'),
    ('PodiumAgency', 2, 'daily'),
    ('PodiumAgency', 3, 'daily'),
    ('PodiumCharm', 1, 'daily'),
    ('PodiumCharm', 2, 'daily'),
    ('PodiumCharm', 3, 'daily'),
    ('PodiumWealth', 1, 'daily'),
    ('PodiumWealth', 2, 'daily'),
    ('PodiumWealth', 3, 'daily')
) AS v(category, rank_position, ranking_type)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.ranking_assets ra
  WHERE ra.category = v.category
    AND ra.rank_position = v.rank_position
    AND ra.ranking_type = v.ranking_type
);
