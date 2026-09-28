-- Fix empty Charm / Gift / Agency rankings
-- Charm = gifts received (gift_logs by receiver)
-- Gift  = gifts sent (gift_logs by sender)
-- Agency = charm received by agency members (not agency_amount which is always 0)

ALTER TABLE public.charm_rankings
  ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.gift_rankings
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

ALTER TABLE public.charm_rankings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public View Charm Rankings" ON public.charm_rankings;
CREATE POLICY "Public View Charm Rankings"
  ON public.charm_rankings
  FOR SELECT
  TO public
  USING (true);

CREATE OR REPLACE FUNCTION public.refresh_charm_rankings()
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

    DELETE FROM public.charm_rankings WHERE ranking_type = v_type;

    INSERT INTO public.charm_rankings (id, user_id, score, rank, ranking_type)
    SELECT
      gen_random_uuid(),
      receiver_id,
      total_score,
      row_number() OVER (ORDER BY total_score DESC),
      v_type
    FROM (
      SELECT
        gl.receiver_id,
        COALESCE(SUM(gl.amount), 0)::bigint AS total_score
      FROM public.gift_logs gl
      WHERE gl.created_at >= v_start
        AND gl.receiver_id IS NOT NULL
      GROUP BY gl.receiver_id
      HAVING COALESCE(SUM(gl.amount), 0) > 0
    ) agg;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_gift_rankings()
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

    DELETE FROM public.gift_rankings WHERE ranking_type = v_type;

    INSERT INTO public.gift_rankings (id, user_id, score, rank, ranking_type)
    SELECT
      gen_random_uuid(),
      sender_id,
      total_score,
      row_number() OVER (ORDER BY total_score DESC),
      v_type
    FROM (
      SELECT
        gl.sender_id,
        COALESCE(SUM(gl.amount), 0)::bigint AS total_score
      FROM public.gift_logs gl
      WHERE gl.created_at >= v_start
        AND gl.sender_id IS NOT NULL
      GROUP BY gl.sender_id
      HAVING COALESCE(SUM(gl.amount), 0) > 0
    ) agg;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_agency_rankings()
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

    DELETE FROM public.agency_rankings WHERE ranking_type = v_type;

    -- Score = charm received by hosts in the agency (gift_logs.amount to members)
    INSERT INTO public.agency_rankings (agency_id, score, rank, ranking_type, updated_at)
    SELECT
      agency_id,
      total_score,
      row_number() OVER (ORDER BY total_score DESC),
      v_type,
      now()
    FROM (
      SELECT
        am.agency_id,
        COALESCE(SUM(gl.amount), 0)::bigint AS total_score
      FROM public.agency_members am
      JOIN public.agencies a ON a.id = am.agency_id AND COALESCE(a.is_active, true) = true
      JOIN public.gift_logs gl
        ON gl.receiver_id = am.user_id
       AND gl.created_at >= v_start
      GROUP BY am.agency_id
      HAVING COALESCE(SUM(gl.amount), 0) > 0
    ) agg;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_charm_rankings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_gift_rankings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_agency_rankings() TO anon, authenticated, service_role;

SELECT public.refresh_charm_rankings();
SELECT public.refresh_gift_rankings();
SELECT public.refresh_agency_rankings();
