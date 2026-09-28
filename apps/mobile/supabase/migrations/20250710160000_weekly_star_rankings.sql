-- Weekly Star: receiver-based rankings from admin-tagged gifts.
-- Also extends party_events.event_kind to allow weekly_star_native.

-- ---------------------------------------------------------------------------
-- Allow weekly_star_native event kind
-- ---------------------------------------------------------------------------
ALTER TABLE public.party_events
  DROP CONSTRAINT IF EXISTS party_events_event_kind_check;

ALTER TABLE public.party_events
  ADD CONSTRAINT party_events_event_kind_check
  CHECK (event_kind IN ('cp_native', 'webview', 'weekly_star_native'));

-- ---------------------------------------------------------------------------
-- Rankings table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.weekly_star_rankings (
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

CREATE INDEX IF NOT EXISTS idx_weekly_star_rankings_event_period_rank
  ON public.weekly_star_rankings (party_event_id, period_key, rank);

ALTER TABLE public.weekly_star_rankings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read weekly star rankings" ON public.weekly_star_rankings;
CREATE POLICY "Public read weekly star rankings"
  ON public.weekly_star_rankings
  FOR SELECT
  TO public
  USING (true);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._weekly_star_gift_ids(p_event_id uuid)
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
    COALESCE(v_cfg->'weekly_star_gift_ids', '[]'::jsonb)
  ) AS t(x)
  WHERE x ~ '^[0-9a-fA-F-]{36}$';

  RETURN COALESCE(v_ids, ARRAY[]::uuid[]);
END;
$$;

CREATE OR REPLACE FUNCTION public._weekly_star_event_window(
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

CREATE OR REPLACE FUNCTION public._weekly_star_iso_week_key(p_ts timestamptz DEFAULT now())
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT to_char(p_ts AT TIME ZONE 'UTC', 'IYYY') || '-W' ||
         to_char(p_ts AT TIME ZONE 'UTC', 'IW');
$$;

CREATE OR REPLACE FUNCTION public._weekly_star_iso_week_bounds(
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

-- Materialize rankings for one period window into period_key
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
    SUM(gl.amount)::bigint,
    row_number() OVER (ORDER BY SUM(gl.amount) DESC)::int,
    p_period_key,
    p_start,
    p_end,
    now()
  FROM public.gift_logs gl
  WHERE gl.gift_id = ANY (p_gift_ids)
    AND gl.created_at >= p_start
    AND gl.created_at < p_end
    AND gl.receiver_id IS NOT NULL
  GROUP BY gl.receiver_id
  HAVING SUM(gl.amount) > 0;
END;
$$;

-- ---------------------------------------------------------------------------
-- refresh_weekly_star_rankings
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_weekly_star_rankings(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gift_ids uuid[];
  v_event_start timestamptz;
  v_event_end timestamptz;
  v_this_start timestamptz;
  v_this_end timestamptz;
  v_last_start timestamptz;
  v_last_end timestamptz;
  v_win_start timestamptz;
  v_win_end timestamptz;
  v_last_key text;
BEGIN
  v_gift_ids := public._weekly_star_gift_ids(p_event_id);
  SELECT o_start, o_end INTO v_event_start, v_event_end
  FROM public._weekly_star_event_window(p_event_id);

  SELECT o_start, o_end INTO v_this_start, v_this_end
  FROM public._weekly_star_iso_week_bounds(now());

  v_last_start := v_this_start - interval '1 week';
  v_last_end := v_this_start;
  v_last_key := public._weekly_star_iso_week_key(v_last_start);

  -- This week (also stored as period_key = 'current')
  v_win_start := GREATEST(v_event_start, v_this_start);
  v_win_end := LEAST(v_event_end, v_this_end, now() + interval '1 second');
  IF v_win_start < v_win_end THEN
    PERFORM public._weekly_star_materialize_period(
      p_event_id, 'current', v_win_start, v_win_end, v_gift_ids
    );
  ELSE
    DELETE FROM public.weekly_star_rankings
    WHERE party_event_id = p_event_id AND period_key = 'current';
  END IF;

  -- Last ISO week snapshot
  v_win_start := GREATEST(v_event_start, v_last_start);
  v_win_end := LEAST(v_event_end, v_last_end);
  IF v_win_start < v_win_end THEN
    PERFORM public._weekly_star_materialize_period(
      p_event_id, v_last_key, v_win_start, v_win_end, v_gift_ids
    );
    -- Alias for easy client fetch
    PERFORM public._weekly_star_materialize_period(
      p_event_id, 'last', v_win_start, v_win_end, v_gift_ids
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_weekly_star_rankings(uuid)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_weekly_star_rankings
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_weekly_star_rankings(
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
  FROM public.weekly_star_rankings r
  LEFT JOIN public.users u ON u.id = r.user_id
  WHERE r.party_event_id = p_event_id
    AND r.period_key = v_key
  ORDER BY r.rank ASC
  LIMIT GREATEST(COALESCE(p_limit, 50), 1)
  OFFSET GREATEST(COALESCE(p_offset, 0), 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_weekly_star_rankings(uuid, text, int, int)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_my_weekly_star_rank
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_weekly_star_rank(
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
  FROM public.weekly_star_rankings r
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

GRANT EXECUTE ON FUNCTION public.get_my_weekly_star_rank(uuid, text)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_weekly_star_last_week_winner
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_weekly_star_last_week_winner(p_event_id uuid)
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
  FROM public.weekly_star_rankings r
  LEFT JOIN public.users u ON u.id = r.user_id
  WHERE r.party_event_id = p_event_id
    AND r.period_key = 'last'
    AND r.rank = 1
  LIMIT 1;

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

GRANT EXECUTE ON FUNCTION public.get_weekly_star_last_week_winner(uuid)
  TO anon, authenticated, service_role;
