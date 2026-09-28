-- Game Star: count only admin-selected games (action_config.game_star_game_ids).
-- Links a game_win via:
--   1) transactions.reference_id = game_configs.id, OR
--   2) transactions.reference_id = game_rounds.id → game_rounds.game_id

CREATE OR REPLACE FUNCTION public._game_star_game_ids(p_event_id uuid)
RETURNS uuid[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb;
  v_ids uuid[];
BEGIN
  SELECT action_config INTO v_cfg
  FROM public.party_events
  WHERE id = p_event_id;

  IF v_cfg IS NULL THEN
    RETURN ARRAY[]::uuid[];
  END IF;

  SELECT COALESCE(array_agg(x::uuid), ARRAY[]::uuid[])
  INTO v_ids
  FROM jsonb_array_elements_text(
    COALESCE(v_cfg->'game_star_game_ids', '[]'::jsonb)
  ) AS t(x)
  WHERE x ~ '^[0-9a-fA-F-]{36}$';

  RETURN COALESCE(v_ids, ARRAY[]::uuid[]);
END;
$$;

CREATE OR REPLACE FUNCTION public._game_star_materialize_period(
  p_event_id uuid,
  p_period_key text,
  p_start timestamptz,
  p_end timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_game_ids uuid[];
BEGIN
  DELETE FROM public.game_star_rankings
  WHERE party_event_id = p_event_id
    AND period_key = p_period_key;

  v_game_ids := public._game_star_game_ids(p_event_id);

  -- No selected games → empty ranking for this period
  IF cardinality(v_game_ids) = 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.game_star_rankings (
    party_event_id, user_id, score, rank,
    period_key, period_start, period_end, updated_at
  )
  SELECT
    p_event_id,
    t.user_id,
    SUM(t.amount)::bigint,
    row_number() OVER (ORDER BY SUM(t.amount) DESC)::int,
    p_period_key,
    p_start,
    p_end,
    now()
  FROM public.transactions t
  WHERE t.transaction_type = 'game_win'
    AND t.created_at >= p_start
    AND t.created_at < p_end
    AND t.user_id IS NOT NULL
    AND (
      t.reference_id = ANY (v_game_ids)
      OR EXISTS (
        SELECT 1
        FROM public.game_rounds gr
        WHERE gr.id = t.reference_id
          AND gr.game_id = ANY (v_game_ids)
      )
    )
  GROUP BY t.user_id
  HAVING SUM(t.amount) > 0;
END;
$$;
