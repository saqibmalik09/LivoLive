-- Game rankings from coin wins in games (transactions.game_win).

CREATE TABLE IF NOT EXISTS public.game_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  score bigint NOT NULL DEFAULT 0,
  rank int NOT NULL DEFAULT 0,
  ranking_type text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, ranking_type)
);

CREATE INDEX IF NOT EXISTS idx_game_rankings_type_rank
  ON public.game_rankings (ranking_type, rank);

ALTER TABLE public.game_rankings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read game rankings" ON public.game_rankings;
CREATE POLICY "Public read game rankings"
  ON public.game_rankings
  FOR SELECT
  TO public
  USING (true);

CREATE OR REPLACE FUNCTION public.refresh_game_rankings()
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

    DELETE FROM public.game_rankings WHERE ranking_type = v_type;

    INSERT INTO public.game_rankings (user_id, score, rank, ranking_type, updated_at)
    SELECT
      user_id,
      total_score,
      row_number() OVER (ORDER BY total_score DESC),
      v_type,
      now()
    FROM (
      SELECT
        t.user_id,
        COALESCE(SUM(t.amount), 0)::bigint AS total_score
      FROM public.transactions t
      WHERE t.transaction_type = 'game_win'
        AND t.created_at >= v_start
      GROUP BY t.user_id
      HAVING COALESCE(SUM(t.amount), 0) > 0
    ) agg;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_game_rankings() TO anon, authenticated, service_role;
