-- Room ranking board: total gift coins sent inside each room (by period).
-- Mirrors refresh_gift_rankings / refresh_charm_rankings.

ALTER TABLE public.room_rankings
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

CREATE OR REPLACE FUNCTION public.refresh_room_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
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

    DELETE FROM public.room_rankings WHERE ranking_type = v_type;

    INSERT INTO public.room_rankings (id, room_id, score, rank, ranking_type, updated_at)
    SELECT
      gen_random_uuid(),
      room_id,
      total_score,
      row_number() OVER (ORDER BY total_score DESC),
      v_type,
      now()
    FROM (
      SELECT
        gl.room_id,
        COALESCE(SUM(gl.amount), 0)::bigint AS total_score
      FROM public.gift_logs gl
      WHERE gl.created_at >= v_start
        AND gl.room_id IS NOT NULL
      GROUP BY gl.room_id
      HAVING COALESCE(SUM(gl.amount), 0) > 0
    ) agg;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_room_rankings() TO anon, authenticated, service_role;

SELECT public.refresh_room_rankings();
