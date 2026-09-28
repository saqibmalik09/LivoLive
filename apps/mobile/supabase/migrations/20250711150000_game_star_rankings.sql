-- Game Star: game_win-based rankings for party events.
-- Extends party_events.event_kind with game_star_native.

-- ---------------------------------------------------------------------------
-- Allow game_star_native event kind
-- ---------------------------------------------------------------------------
ALTER TABLE public.party_events
  DROP CONSTRAINT IF EXISTS party_events_event_kind_check;

ALTER TABLE public.party_events
  ADD CONSTRAINT party_events_event_kind_check
  CHECK (event_kind IN ('cp_native', 'webview', 'weekly_star_native', 'game_star_native'));

-- ---------------------------------------------------------------------------
-- Rankings table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.game_star_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_event_id uuid NOT NULL REFERENCES public.party_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  score bigint NOT NULL DEFAULT 0,
  rank int NOT NULL DEFAULT 0,
  period_key text NOT NULL DEFAULT 'current',
  period_start timestamptz,
  period_end timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (party_event_id, user_id, period_key)
);

CREATE INDEX IF NOT EXISTS idx_game_star_rankings_event_period_rank
  ON public.game_star_rankings (party_event_id, period_key, rank);

ALTER TABLE public.game_star_rankings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read game star rankings" ON public.game_star_rankings;
CREATE POLICY "Public read game star rankings"
  ON public.game_star_rankings
  FOR SELECT
  TO public
  USING (true);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._game_star_event_window(
  p_event_id uuid,
  OUT o_start timestamptz,
  OUT o_end timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  SELECT start_at, end_at INTO v_start, v_end
  FROM public.party_events
  WHERE id = p_event_id;

  o_start := COALESCE(v_start, date_trunc('week', now()) - interval '8 weeks');
  o_end := COALESCE(v_end, now() + interval '1 year');
END;
$$;

CREATE OR REPLACE FUNCTION public._game_star_iso_week_key(p_ts timestamptz DEFAULT now())
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT to_char(p_ts AT TIME ZONE 'UTC', 'IYYY') || '-W' ||
         to_char(p_ts AT TIME ZONE 'UTC', 'IW');
$$;

CREATE OR REPLACE FUNCTION public._game_star_iso_week_bounds(
  p_ts timestamptz,
  OUT o_start timestamptz,
  OUT o_end timestamptz
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  o_start := date_trunc('week', p_ts);
  o_end := o_start + interval '1 week';
END;
$$;

-- Materialize rankings for one period from transactions.game_win
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
BEGIN
  DELETE FROM public.game_star_rankings
  WHERE party_event_id = p_event_id
    AND period_key = p_period_key;

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
  GROUP BY t.user_id
  HAVING SUM(t.amount) > 0;
END;
$$;

-- ---------------------------------------------------------------------------
-- refresh_game_star_rankings
-- Materializes current + last week aliases, plus last 8 ISO weeks for history.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_game_star_rankings(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_start timestamptz;
  v_event_end timestamptz;
  v_this_start timestamptz;
  v_this_end timestamptz;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_win_start timestamptz;
  v_win_end timestamptz;
  v_week_key text;
  v_i int;
BEGIN
  SELECT o_start, o_end INTO v_event_start, v_event_end
  FROM public._game_star_event_window(p_event_id);

  SELECT o_start, o_end INTO v_this_start, v_this_end
  FROM public._game_star_iso_week_bounds(now());

  -- This week → period_key = 'current'
  v_win_start := GREATEST(v_event_start, v_this_start);
  v_win_end := LEAST(v_event_end, v_this_end, now() + interval '1 second');
  IF v_win_start < v_win_end THEN
    PERFORM public._game_star_materialize_period(
      p_event_id, 'current', v_win_start, v_win_end
    );
  ELSE
    DELETE FROM public.game_star_rankings
    WHERE party_event_id = p_event_id AND period_key = 'current';
  END IF;

  -- Last 8 completed/current ISO weeks (i=0 is this week, i=1 is last, …)
  FOR v_i IN 0..7 LOOP
    v_week_start := v_this_start - (v_i * interval '1 week');
    v_week_end := v_week_start + interval '1 week';
    v_week_key := public._game_star_iso_week_key(v_week_start);

    v_win_start := GREATEST(v_event_start, v_week_start);
    v_win_end := LEAST(v_event_end, v_week_end);
    IF v_i = 0 THEN
      v_win_end := LEAST(v_win_end, now() + interval '1 second');
    END IF;

    IF v_win_start < v_win_end THEN
      PERFORM public._game_star_materialize_period(
        p_event_id, v_week_key, v_win_start, v_win_end
      );
    END IF;

    -- Alias last completed week as 'last'
    IF v_i = 1 THEN
      IF v_win_start < v_win_end THEN
        PERFORM public._game_star_materialize_period(
          p_event_id, 'last', v_win_start, v_win_end
        );
      ELSE
        DELETE FROM public.game_star_rankings
        WHERE party_event_id = p_event_id AND period_key = 'last';
      END IF;
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_game_star_rankings(uuid)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_game_star_rankings
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_game_star_rankings(
  p_event_id uuid,
  p_period_key text DEFAULT 'current',
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
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
BEGIN
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
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_game_star_rankings(uuid, text, int, int)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_my_game_star_rank
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_game_star_rank(
  p_event_id uuid,
  p_period_key text DEFAULT 'current'
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
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT r.rank, r.score
  INTO v_rank, v_score
  FROM public.game_star_rankings r
  WHERE r.party_event_id = p_event_id
    AND r.period_key = v_key
    AND r.user_id = v_uid
  LIMIT 1;

  SELECT username, avatar_url, short_id::text
  INTO v_name, v_avatar, v_short
  FROM public.users
  WHERE id = v_uid;

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

GRANT EXECUTE ON FUNCTION public.get_my_game_star_rank(uuid, text)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_game_star_featured_winner — last-week #1 for throne header
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_game_star_featured_winner(p_event_id uuid)
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
    r.user_id,
    r.score,
    r.rank,
    COALESCE(u.username, 'User') AS username,
    u.avatar_url,
    COALESCE(u.short_id::text, '') AS short_id
  INTO v_row
  FROM public.game_star_rankings r
  LEFT JOIN public.users u ON u.id = r.user_id
  WHERE r.party_event_id = p_event_id
    AND r.period_key = 'last'
    AND r.rank = 1
  LIMIT 1;

  IF NOT FOUND THEN
    -- Fallback: current week #1
    SELECT
      r.user_id,
      r.score,
      r.rank,
      COALESCE(u.username, 'User') AS username,
      u.avatar_url,
      COALESCE(u.short_id::text, '') AS short_id
    INTO v_row
    FROM public.game_star_rankings r
    LEFT JOIN public.users u ON u.id = r.user_id
    WHERE r.party_event_id = p_event_id
      AND r.period_key = 'current'
      AND r.rank = 1
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

GRANT EXECUTE ON FUNCTION public.get_game_star_featured_winner(uuid)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_game_star_history — last N ISO weeks, top-3 each
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_game_star_history(
  p_event_id uuid,
  p_weeks int DEFAULT 4
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
BEGIN
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
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_game_star_history(uuid, int)
  TO anon, authenticated, service_role;
