-- Per-room user contribution rankings (gifts sent in room, by sender).

CREATE INDEX IF NOT EXISTS idx_gift_logs_room_created
  ON public.gift_logs (room_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_gift_logs_room_sender_created
  ON public.gift_logs (room_id, sender_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.get_room_contribution_rankings(
  p_room_id uuid,
  p_ranking_type text
)
RETURNS TABLE (
  user_id uuid,
  score bigint,
  rank int
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH bounds AS (
    SELECT CASE
      WHEN lower(p_ranking_type) IN ('weekly', 'week') THEN date_trunc('week', now())
      ELSE date_trunc('day', now())
    END AS v_start
  ),
  agg AS (
    SELECT
      gl.sender_id,
      SUM(gl.amount)::bigint AS total_score
    FROM public.gift_logs gl
    CROSS JOIN bounds b
    WHERE gl.room_id = p_room_id
      AND gl.sender_id IS NOT NULL
      AND gl.created_at >= b.v_start
    GROUP BY gl.sender_id
    HAVING SUM(gl.amount) > 0
  )
  SELECT
    sender_id AS user_id,
    total_score AS score,
    row_number() OVER (ORDER BY total_score DESC)::int AS rank
  FROM agg
  ORDER BY rank
  LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION public.get_room_contribution_rankings(uuid, text)
  TO anon, authenticated, service_role;
