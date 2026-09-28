-- Weekly Star: score by admin-configured points per gift (max 4 slots).
-- action_config.weekly_star_gifts = [{ "gift_id": "uuid", "points": 500 }, ...]
-- Falls back to weekly_star_gift_ids + gift_logs.amount if new key missing.

CREATE OR REPLACE FUNCTION public._weekly_star_gift_points(p_event_id uuid)
RETURNS TABLE (gift_id uuid, points bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb;
BEGIN
  SELECT action_config INTO v_cfg
  FROM public.party_events
  WHERE id = p_event_id;

  IF v_cfg IS NULL THEN
    RETURN;
  END IF;

  -- Preferred: weekly_star_gifts [{gift_id, points}]
  IF jsonb_typeof(v_cfg->'weekly_star_gifts') = 'array'
     AND jsonb_array_length(v_cfg->'weekly_star_gifts') > 0 THEN
    RETURN QUERY
    SELECT
      (elem->>'gift_id')::uuid,
      GREATEST(COALESCE((elem->>'points')::bigint, 0), 0)
    FROM jsonb_array_elements(v_cfg->'weekly_star_gifts') AS elem
    WHERE (elem->>'gift_id') ~ '^[0-9a-fA-F-]{36}$'
      AND COALESCE((elem->>'points')::bigint, 0) > 0
    LIMIT 4;
    RETURN;
  END IF;

  -- Legacy: weekly_star_gift_ids — use gift_logs.amount as points (1 coin = 1 pt)
  RETURN QUERY
  SELECT x::uuid, 0::bigint
  FROM jsonb_array_elements_text(
    COALESCE(v_cfg->'weekly_star_gift_ids', '[]'::jsonb)
  ) AS t(x)
  WHERE x ~ '^[0-9a-fA-F-]{36}$'
  LIMIT 4;
END;
$$;

CREATE OR REPLACE FUNCTION public._weekly_star_gift_ids(p_event_id uuid)
RETURNS uuid[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ids uuid[];
BEGIN
  SELECT COALESCE(array_agg(g.gift_id), ARRAY[]::uuid[])
  INTO v_ids
  FROM public._weekly_star_gift_points(p_event_id) g;

  RETURN COALESCE(v_ids, ARRAY[]::uuid[]);
END;
$$;

CREATE OR REPLACE FUNCTION public._weekly_star_materialize_period(
  p_event_id uuid,
  p_period_key text,
  p_start timestamptz,
  p_end timestamptz,
  p_gift_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.weekly_star_rankings
  WHERE party_event_id = p_event_id
    AND period_key = p_period_key;

  IF cardinality(p_gift_ids) = 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.weekly_star_rankings (
    party_event_id, user_id, score, rank,
    period_key, period_start, period_end, updated_at
  )
  SELECT
    p_event_id,
    gl.receiver_id,
    SUM(
      CASE
        WHEN gp.points > 0 THEN gp.points
        ELSE COALESCE(gl.amount, 0)
      END
    )::bigint,
    row_number() OVER (
      ORDER BY SUM(
        CASE
          WHEN gp.points > 0 THEN gp.points
          ELSE COALESCE(gl.amount, 0)
        END
      ) DESC
    )::int,
    p_period_key,
    p_start,
    p_end,
    now()
  FROM public.gift_logs gl
  INNER JOIN public._weekly_star_gift_points(p_event_id) gp
    ON gp.gift_id = gl.gift_id
  WHERE gl.gift_id = ANY (p_gift_ids)
    AND gl.created_at >= p_start
    AND gl.created_at < p_end
    AND gl.receiver_id IS NOT NULL
  GROUP BY gl.receiver_id
  HAVING SUM(
    CASE
      WHEN gp.points > 0 THEN gp.points
      ELSE COALESCE(gl.amount, 0)
    END
  ) > 0;
END;
$$;
