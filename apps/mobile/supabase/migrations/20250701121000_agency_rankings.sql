-- Agency rankings from earning_logs agency_amount per period.

CREATE TABLE IF NOT EXISTS public.agency_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id uuid NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  score bigint NOT NULL DEFAULT 0,
  rank int NOT NULL DEFAULT 0,
  ranking_type text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (agency_id, ranking_type)
);

CREATE INDEX IF NOT EXISTS idx_agency_rankings_type_rank
  ON public.agency_rankings (ranking_type, rank);

ALTER TABLE public.agency_rankings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read agency rankings" ON public.agency_rankings;
CREATE POLICY "Public read agency rankings"
  ON public.agency_rankings
  FOR SELECT
  TO public
  USING (true);

CREATE OR REPLACE FUNCTION public.refresh_agency_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    IF v_type = 'daily' THEN
      v_start := date_trunc('day', now());
    ELSIF v_type = 'weekly' THEN
      v_start := date_trunc('week', now());
    ELSE
      v_start := date_trunc('month', now());
    END IF;

    DELETE FROM public.agency_rankings WHERE ranking_type = v_type;

    INSERT INTO public.agency_rankings (agency_id, score, rank, ranking_type, updated_at)
    SELECT
      agency_id,
      total_score,
      row_number() OVER (ORDER BY total_score DESC),
      v_type,
      now()
    FROM (
      SELECT
        a.id AS agency_id,
        COALESCE(SUM(el.agency_amount), 0)::bigint AS total_score
      FROM public.agencies a
      LEFT JOIN public.earning_logs el
        ON el.agency_owner_id = a.owner_id
       AND el.created_at >= v_start
      WHERE COALESCE(a.is_active, true) = true
      GROUP BY a.id
      HAVING COALESCE(SUM(el.agency_amount), 0) > 0
    ) agg;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_agency_rankings() TO anon, authenticated, service_role;

-- Seed weekly ranking_assets rows for Agency (frames uploaded via admin).
INSERT INTO public.ranking_assets (category, rank_position, ranking_type, frame_url, badge_url)
SELECT v.category, v.rank_position, v.ranking_type, '', ''
FROM (
  VALUES
    ('Agency', 1, 'weekly'),
    ('Agency', 2, 'weekly'),
    ('Agency', 3, 'weekly'),
    ('Agency', 1, 'daily'),
    ('Agency', 2, 'daily'),
    ('Agency', 3, 'daily'),
    ('Agency', 1, 'monthly'),
    ('Agency', 2, 'monthly'),
    ('Agency', 3, 'monthly')
) AS v(category, rank_position, ranking_type)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.ranking_assets ra
  WHERE ra.category = v.category
    AND ra.rank_position = v.rank_position
    AND ra.ranking_type = v.ranking_type
);
