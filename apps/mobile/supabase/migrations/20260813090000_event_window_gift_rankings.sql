-- Date-window gift rankings for WebView events (e.g. 14 August).
-- Reuses weekly_star_rankings + gift-point helpers. period_key = 'window'.
-- Scores tagged gift receives between party_events.start_at and end_at (not ISO weeks).

CREATE OR REPLACE FUNCTION public.refresh_event_window_gift_rankings(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gift_ids uuid[];
  v_event_start timestamptz;
  v_event_end timestamptz;
  v_win_start timestamptz;
  v_win_end timestamptz;
BEGIN
  v_gift_ids := public._weekly_star_gift_ids(p_event_id);
  SELECT o_start, o_end INTO v_event_start, v_event_end
  FROM public._weekly_star_event_window(p_event_id);

  v_win_start := v_event_start;
  v_win_end := LEAST(v_event_end, now() + interval '1 second');

  IF v_win_start < v_win_end THEN
    PERFORM public._weekly_star_materialize_period(
      p_event_id, 'window', v_win_start, v_win_end, v_gift_ids
    );
  ELSE
    DELETE FROM public.weekly_star_rankings
    WHERE party_event_id = p_event_id
      AND period_key = 'window';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_event_window_gift_rankings(uuid)
  TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_event_window_gift_rankings(
  p_event_id uuid,
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
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.get_weekly_star_rankings(
    p_event_id,
    'window',
    p_limit,
    p_offset
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_event_window_gift_rankings(uuid, int, int)
  TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_my_event_window_gift_rank(p_event_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.get_my_weekly_star_rank(p_event_id, 'window');
$$;

GRANT EXECUTE ON FUNCTION public.get_my_event_window_gift_rank(uuid)
  TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_event_window_gift_leader(p_event_id uuid)
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
    AND r.period_key = 'window'
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

GRANT EXECUTE ON FUNCTION public.get_event_window_gift_leader(uuid)
  TO anon, authenticated, service_role;
