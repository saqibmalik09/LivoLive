-- Per-game Game Star rankings / history (optional p_game_id).

-- Drop previous signatures so we can add p_game_id.
DROP FUNCTION IF EXISTS public.get_game_star_rankings(uuid, text, int, int);
DROP FUNCTION IF EXISTS public.get_my_game_star_rank(uuid, text);
DROP FUNCTION IF EXISTS public.get_game_star_featured_winner(uuid);
DROP FUNCTION IF EXISTS public.get_game_star_history(uuid, int);

CREATE OR REPLACE FUNCTION public._game_star_period_bounds(
  p_event_id uuid,
  p_period_key text,
  OUT o_start timestamptz,
  OUT o_end timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_start timestamptz;
  v_event_end timestamptz;
  v_this_start timestamptz;
  v_this_end timestamptz;
  v_key text := COALESCE(NULLIF(trim(p_period_key), ''), 'current');
  v_week_start timestamptz;
  v_i int;
BEGIN
  SELECT ew.o_start, ew.o_end INTO v_event_start, v_event_end
  FROM public._game_star_event_window(p_event_id) AS ew;

  SELECT bw.o_start, bw.o_end INTO v_this_start, v_this_end
  FROM public._game_star_iso_week_bounds(now()) AS bw;

  IF v_key = 'current' THEN
    o_start := GREATEST(v_event_start, v_this_start);
    o_end := LEAST(v_event_end, v_this_end, now() + interval '1 second');
  ELSIF v_key = 'last' THEN
    o_start := GREATEST(v_event_start, v_this_start - interval '1 week');
    o_end := LEAST(v_event_end, v_this_start);
  ELSIF v_key ~ '^[0-9]{4}-W[0-9]{2}$' THEN
    FOR v_i IN 0..11 LOOP
      v_week_start := v_this_start - (v_i * interval '1 week');
      IF public._game_star_iso_week_key(v_week_start) = v_key THEN
        o_start := GREATEST(v_event_start, v_week_start);
        o_end := LEAST(
          v_event_end,
          v_week_start + interval '1 week',
          CASE WHEN v_i = 0 THEN now() + interval '1 second' ELSE v_week_start + interval '1 week' END
        );
        RETURN;
      END IF;
    END LOOP;
    o_start := v_event_start;
    o_end := v_event_start;
  ELSE
    o_start := GREATEST(v_event_start, v_this_start);
    o_end := LEAST(v_event_end, v_this_end, now() + interval '1 second');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_game_star_rankings(
  p_event_id uuid,
  p_period_key text DEFAULT 'current',
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_game_id uuid DEFAULT NULL
)
RETURNS TABLE (
  user_id uuid,
  username text,
  avatar_url text,
  short_id text,
  score bigint,
  rank int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key text := COALESCE(NULLIF(trim(p_period_key), ''), 'current');
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  -- All selected games: use materialized table
  IF p_game_id IS NULL THEN
    RETURN QUERY
    SELECT
      r.user_id,
      COALESCE(u.username, 'User')::text,
      u.avatar_url::text,
      COALESCE(u.short_id::text, '')::text,
      r.score,
      r.rank
    FROM public.game_star_rankings r
    LEFT JOIN public.users u ON u.id = r.user_id
    WHERE r.party_event_id = p_event_id
      AND r.period_key = v_key
    ORDER BY r.rank ASC
    LIMIT GREATEST(COALESCE(p_limit, 50), 1)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
    RETURN;
  END IF;

  -- Single game: live aggregate from transactions
  SELECT pb.o_start, pb.o_end INTO v_start, v_end
  FROM public._game_star_period_bounds(p_event_id, v_key) AS pb;

  IF v_start IS NULL OR v_end IS NULL OR NOT (v_start < v_end) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    agg.user_id,
    COALESCE(u.username, 'User')::text,
    u.avatar_url::text,
    COALESCE(u.short_id::text, '')::text,
    agg.score,
    agg.rank
  FROM (
    SELECT
      t.user_id,
      SUM(t.amount)::bigint AS score,
      row_number() OVER (ORDER BY SUM(t.amount) DESC)::int AS rank
    FROM public.transactions t
    WHERE t.transaction_type = 'game_win'
      AND t.created_at >= v_start
      AND t.created_at < v_end
      AND t.user_id IS NOT NULL
      AND (
        t.reference_id = p_game_id
        OR EXISTS (
          SELECT 1 FROM public.game_rounds gr
          WHERE gr.id = t.reference_id AND gr.game_id = p_game_id
        )
      )
    GROUP BY t.user_id
    HAVING SUM(t.amount) > 0
  ) agg
  LEFT JOIN public.users u ON u.id = agg.user_id
  ORDER BY agg.rank ASC
  LIMIT GREATEST(COALESCE(p_limit, 50), 1)
  OFFSET GREATEST(COALESCE(p_offset, 0), 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_game_star_rankings(uuid, text, int, int, uuid)
  TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_my_game_star_rank(
  p_event_id uuid,
  p_period_key text DEFAULT 'current',
  p_game_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_key text := COALESCE(NULLIF(trim(p_period_key), ''), 'current');
  v_rank int;
  v_score bigint;
  v_name text;
  v_avatar text;
  v_short text;
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT username, avatar_url, short_id::text
  INTO v_name, v_avatar, v_short
  FROM public.users
  WHERE id = v_uid;

  IF p_game_id IS NULL THEN
    SELECT r.rank, r.score
    INTO v_rank, v_score
    FROM public.game_star_rankings r
    WHERE r.party_event_id = p_event_id
      AND r.period_key = v_key
      AND r.user_id = v_uid
    LIMIT 1;
  ELSE
    SELECT pb.o_start, pb.o_end INTO v_start, v_end
    FROM public._game_star_period_bounds(p_event_id, v_key) AS pb;

    IF v_start < v_end THEN
      SELECT x.rank, x.score INTO v_rank, v_score
      FROM (
        SELECT
          t.user_id,
          SUM(t.amount)::bigint AS score,
          row_number() OVER (ORDER BY SUM(t.amount) DESC)::int AS rank
        FROM public.transactions t
        WHERE t.transaction_type = 'game_win'
          AND t.created_at >= v_start
          AND t.created_at < v_end
          AND t.user_id IS NOT NULL
          AND (
            t.reference_id = p_game_id
            OR EXISTS (
              SELECT 1 FROM public.game_rounds gr
              WHERE gr.id = t.reference_id AND gr.game_id = p_game_id
            )
          )
        GROUP BY t.user_id
        HAVING SUM(t.amount) > 0
      ) x
      WHERE x.user_id = v_uid
      LIMIT 1;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_uid,
    'rank', v_rank,
    'score', COALESCE(v_score, 0),
    'username', v_name,
    'avatar_url', v_avatar,
    'short_id', COALESCE(v_short, '')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_game_star_rank(uuid, text, uuid)
  TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_game_star_featured_winner(
  p_event_id uuid,
  p_game_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
BEGIN
  SELECT
    g.user_id, g.score, g.rank, g.username, g.avatar_url, g.short_id
  INTO v_row
  FROM public.get_game_star_rankings(p_event_id, 'last', 1, 0, p_game_id) g
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT
      g.user_id, g.score, g.rank, g.username, g.avatar_url, g.short_id
    INTO v_row
    FROM public.get_game_star_rankings(p_event_id, 'current', 1, 0, p_game_id) g
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_row.user_id,
    'score', v_row.score,
    'rank', v_row.rank,
    'username', v_row.username,
    'avatar_url', v_row.avatar_url,
    'short_id', v_row.short_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_game_star_featured_winner(uuid, uuid)
  TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_game_star_history(
  p_event_id uuid,
  p_weeks int DEFAULT 4,
  p_game_id uuid DEFAULT NULL
)
RETURNS TABLE (
  period_key text,
  period_start timestamptz,
  period_end timestamptz,
  user_id uuid,
  username text,
  avatar_url text,
  short_id text,
  score bigint,
  rank int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_weeks int := GREATEST(LEAST(COALESCE(p_weeks, 4), 8), 1);
  v_event_start timestamptz;
  v_event_end timestamptz;
  v_this_start timestamptz;
  v_i int;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_win_start timestamptz;
  v_win_end timestamptz;
  v_week_key text;
BEGIN
  -- All games: use materialized ISO week keys
  IF p_game_id IS NULL THEN
    RETURN QUERY
    WITH week_keys AS (
      SELECT DISTINCT ON (r.period_key)
        r.period_key,
        r.period_start,
        r.period_end
      FROM public.game_star_rankings r
      WHERE r.party_event_id = p_event_id
        AND r.period_key ~ '^[0-9]{4}-W[0-9]{2}$'
        AND r.period_key <> public._game_star_iso_week_key(now())
      ORDER BY r.period_key DESC, r.period_start DESC NULLS LAST
      LIMIT v_weeks
    )
    SELECT
      wk.period_key,
      wk.period_start,
      wk.period_end,
      r.user_id,
      COALESCE(u.username, 'User')::text,
      u.avatar_url::text,
      COALESCE(u.short_id::text, '')::text,
      r.score,
      r.rank
    FROM week_keys wk
    JOIN public.game_star_rankings r
      ON r.party_event_id = p_event_id
     AND r.period_key = wk.period_key
     AND r.rank <= 3
    LEFT JOIN public.users u ON u.id = r.user_id
    ORDER BY wk.period_key DESC, r.rank ASC;
    RETURN;
  END IF;

  -- Single game: live top-3 for last N completed weeks
  SELECT ew.o_start, ew.o_end INTO v_event_start, v_event_end
  FROM public._game_star_event_window(p_event_id) AS ew;
  SELECT bw.o_start INTO v_this_start
  FROM public._game_star_iso_week_bounds(now()) AS bw;

  FOR v_i IN 1..v_weeks LOOP
    v_week_start := v_this_start - (v_i * interval '1 week');
    v_week_end := v_week_start + interval '1 week';
    v_week_key := public._game_star_iso_week_key(v_week_start);
    v_win_start := GREATEST(v_event_start, v_week_start);
    v_win_end := LEAST(v_event_end, v_week_end);

    IF v_win_start < v_win_end THEN
      RETURN QUERY
      SELECT
        v_week_key,
        v_win_start,
        v_win_end,
        agg.user_id,
        COALESCE(u.username, 'User')::text,
        u.avatar_url::text,
        COALESCE(u.short_id::text, '')::text,
        agg.score,
        agg.rank
      FROM (
        SELECT
          t.user_id,
          SUM(t.amount)::bigint AS score,
          row_number() OVER (ORDER BY SUM(t.amount) DESC)::int AS rank
        FROM public.transactions t
        WHERE t.transaction_type = 'game_win'
          AND t.created_at >= v_win_start
          AND t.created_at < v_win_end
          AND t.user_id IS NOT NULL
          AND (
            t.reference_id = p_game_id
            OR EXISTS (
              SELECT 1 FROM public.game_rounds gr
              WHERE gr.id = t.reference_id AND gr.game_id = p_game_id
            )
          )
        GROUP BY t.user_id
        HAVING SUM(t.amount) > 0
      ) agg
      LEFT JOIN public.users u ON u.id = agg.user_id
      WHERE agg.rank <= 3
      ORDER BY agg.rank ASC;
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_game_star_history(uuid, int, uuid)
  TO anon, authenticated, service_role;
