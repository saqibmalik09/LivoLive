-- CP Event rankings: event-scoped couple scores from admin-tagged gifts.

CREATE TABLE IF NOT EXISTS public.cp_event_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_event_id uuid NOT NULL REFERENCES public.party_events(id) ON DELETE CASCADE,
  user_1_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  user_2_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  score bigint NOT NULL DEFAULT 0,
  rank int NOT NULL DEFAULT 0,
  period_key text NOT NULL DEFAULT 'current',
  period_start timestamptz,
  period_end timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (party_event_id, user_1_id, user_2_id, period_key)
);

CREATE INDEX IF NOT EXISTS idx_cp_event_rankings_event_period_rank
  ON public.cp_event_rankings (party_event_id, period_key, rank);

ALTER TABLE public.cp_event_rankings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read cp event rankings" ON public.cp_event_rankings;
CREATE POLICY "Public read cp event rankings"
  ON public.cp_event_rankings
  FOR SELECT
  TO public
  USING (true);

-- ---------------------------------------------------------------------------
-- Helper: extract tagged gift UUIDs from party_events.action_config
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._cp_event_gift_ids(p_event_id uuid)
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
  FROM jsonb_array_elements_text(COALESCE(v_cfg->'cp_gift_ids', '[]'::jsonb)) AS t(x)
  WHERE x ~ '^[0-9a-fA-F-]{36}$';

  RETURN COALESCE(v_ids, ARRAY[]::uuid[]);
END;
$$;

-- ---------------------------------------------------------------------------
-- Helper: event time window (start_at / end_at, with sensible defaults)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._cp_event_window(p_event_id uuid, OUT o_start timestamptz, OUT o_end timestamptz)
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

  o_start := COALESCE(v_start, date_trunc('week', now()));
  o_end := COALESCE(v_end, now() + interval '1 year');
END;
$$;

-- ---------------------------------------------------------------------------
-- refresh_cp_event_rankings: materialize current-period couple scores
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_cp_event_rankings(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gift_ids uuid[];
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  v_gift_ids := public._cp_event_gift_ids(p_event_id);
  SELECT o_start, o_end INTO v_start, v_end FROM public._cp_event_window(p_event_id);

  DELETE FROM public.cp_event_rankings
  WHERE party_event_id = p_event_id
    AND period_key = 'current';

  IF cardinality(v_gift_ids) = 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.cp_event_rankings (
    party_event_id, user_1_id, user_2_id, score, rank,
    period_key, period_start, period_end, updated_at
  )
  SELECT
    p_event_id,
    c.user1_id,
    c.user2_id,
    agg.total_score,
    row_number() OVER (ORDER BY agg.total_score DESC)::int,
    'current',
    v_start,
    v_end,
    now()
  FROM (
    SELECT
      c.id AS couple_id,
      COALESCE(SUM(gl.amount), 0)::bigint AS total_score
    FROM public.couples c
    INNER JOIN public.gift_logs gl
      ON gl.gift_id = ANY (v_gift_ids)
     AND gl.created_at >= v_start
     AND gl.created_at <= v_end
     AND (
       (gl.sender_id = c.user1_id AND gl.receiver_id = c.user2_id)
       OR (gl.sender_id = c.user2_id AND gl.receiver_id = c.user1_id)
     )
    GROUP BY c.id
    HAVING COALESCE(SUM(gl.amount), 0) > 0
  ) agg
  JOIN public.couples c ON c.id = agg.couple_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_cp_event_rankings(uuid) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_cp_event_gift_top: top tagged gifts by coin volume between couples
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_cp_event_gift_top(
  p_event_id uuid,
  p_limit int DEFAULT 10
)
RETURNS TABLE (
  gift_id uuid,
  gift_name text,
  gift_image_url text,
  total_amount bigint,
  top_sender_id uuid,
  top_sender_name text,
  top_sender_avatar text,
  top_receiver_id uuid,
  top_receiver_name text,
  top_receiver_avatar text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gift_ids uuid[];
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  v_gift_ids := public._cp_event_gift_ids(p_event_id);
  SELECT o_start, o_end INTO v_start, v_end FROM public._cp_event_window(p_event_id);

  IF cardinality(v_gift_ids) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH couple_gifts AS (
    SELECT
      gl.gift_id AS gid,
      gl.sender_id,
      gl.receiver_id,
      gl.amount
    FROM public.gift_logs gl
    INNER JOIN public.couples c
      ON (
        (gl.sender_id = c.user1_id AND gl.receiver_id = c.user2_id)
        OR (gl.sender_id = c.user2_id AND gl.receiver_id = c.user1_id)
      )
    WHERE gl.gift_id = ANY (v_gift_ids)
      AND gl.created_at >= v_start
      AND gl.created_at <= v_end
  ),
  gift_totals AS (
    SELECT cg.gid, SUM(cg.amount)::bigint AS total_amount
    FROM couple_gifts cg
    GROUP BY cg.gid
  ),
  pair_totals AS (
    SELECT
      cg.gid,
      cg.sender_id,
      cg.receiver_id,
      SUM(cg.amount)::bigint AS pair_amount
    FROM couple_gifts cg
    GROUP BY cg.gid, cg.sender_id, cg.receiver_id
  ),
  top_pair AS (
    SELECT DISTINCT ON (pt.gid)
      pt.gid,
      pt.sender_id,
      pt.receiver_id
    FROM pair_totals pt
    ORDER BY pt.gid, pt.pair_amount DESC
  )
  SELECT
    gt.gid,
    COALESCE(si.name, 'Gift')::text,
    COALESCE(si.image_url, '')::text,
    gt.total_amount,
    tp.sender_id,
    COALESCE(us.username, 'User')::text,
    us.avatar_url::text,
    tp.receiver_id,
    COALESCE(ur.username, 'User')::text,
    ur.avatar_url::text
  FROM gift_totals gt
  JOIN top_pair tp ON tp.gid = gt.gid
  LEFT JOIN public.shop_items si ON si.id = gt.gid
  LEFT JOIN public.users us ON us.id = tp.sender_id
  LEFT JOIN public.users ur ON ur.id = tp.receiver_id
  ORDER BY gt.total_amount DESC
  LIMIT GREATEST(COALESCE(p_limit, 10), 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_cp_event_gift_top(uuid, int) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_cp_event_weekly_snapshots: last N ISO weeks of top gift + top 3 couples
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_cp_event_weekly_snapshots(
  p_event_id uuid,
  p_weeks int DEFAULT 3
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gift_ids uuid[];
  v_weeks int := GREATEST(COALESCE(p_weeks, 3), 1);
  v_result jsonb := '[]'::jsonb;
  v_i int;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_top_gift jsonb;
  v_top_couples jsonb;
BEGIN
  v_gift_ids := public._cp_event_gift_ids(p_event_id);
  IF cardinality(v_gift_ids) = 0 THEN
    RETURN '[]'::jsonb;
  END IF;

  FOR v_i IN 1..v_weeks LOOP
    -- Previous completed weeks: i=1 → last week, i=2 → week before, etc.
    v_week_start := date_trunc('week', now()) - (v_i * interval '1 week');
    v_week_end := v_week_start + interval '1 week';

    SELECT jsonb_build_object(
      'gift_id', x.gid,
      'gift_name', x.gname,
      'gift_image_url', x.gimg,
      'total_amount', x.total
    )
    INTO v_top_gift
    FROM (
      SELECT
        gl.gift_id AS gid,
        COALESCE(si.name, 'Gift') AS gname,
        COALESCE(si.image_url, '') AS gimg,
        SUM(gl.amount)::bigint AS total
      FROM public.gift_logs gl
      INNER JOIN public.couples c
        ON (
          (gl.sender_id = c.user1_id AND gl.receiver_id = c.user2_id)
          OR (gl.sender_id = c.user2_id AND gl.receiver_id = c.user1_id)
        )
      LEFT JOIN public.shop_items si ON si.id = gl.gift_id
      WHERE gl.gift_id = ANY (v_gift_ids)
        AND gl.created_at >= v_week_start
        AND gl.created_at < v_week_end
      GROUP BY gl.gift_id, si.name, si.image_url
      ORDER BY SUM(gl.amount) DESC
      LIMIT 1
    ) x;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.rank), '[]'::jsonb)
    INTO v_top_couples
    FROM (
      SELECT
        row_number() OVER (ORDER BY SUM(gl.amount) DESC)::int AS rank,
        c.user1_id AS user_1_id,
        c.user2_id AS user_2_id,
        SUM(gl.amount)::bigint AS score,
        u1.username AS user1_name,
        u1.avatar_url AS user1_avatar,
        u2.username AS user2_name,
        u2.avatar_url AS user2_avatar
      FROM public.gift_logs gl
      INNER JOIN public.couples c
        ON (
          (gl.sender_id = c.user1_id AND gl.receiver_id = c.user2_id)
          OR (gl.sender_id = c.user2_id AND gl.receiver_id = c.user1_id)
        )
      LEFT JOIN public.users u1 ON u1.id = c.user1_id
      LEFT JOIN public.users u2 ON u2.id = c.user2_id
      WHERE gl.gift_id = ANY (v_gift_ids)
        AND gl.created_at >= v_week_start
        AND gl.created_at < v_week_end
      GROUP BY c.id, c.user1_id, c.user2_id, u1.username, u1.avatar_url, u2.username, u2.avatar_url
      ORDER BY SUM(gl.amount) DESC
      LIMIT 3
    ) t;

    -- Only include weeks that have at least one couple score
    IF v_top_couples IS NOT NULL AND jsonb_array_length(v_top_couples) > 0 THEN
      v_result := v_result || jsonb_build_array(
        jsonb_build_object(
          'week_index', v_i,
          'period_start', v_week_start,
          'period_end', v_week_end - interval '1 second',
          'top_gift', COALESCE(v_top_gift, 'null'::jsonb),
          'top_couples', v_top_couples
        )
      );
    END IF;
  END LOOP;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_cp_event_weekly_snapshots(uuid, int) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_my_cp_event_rank: sticky bar for current user's couple
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_cp_event_rank(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_rank int;
  v_score bigint;
  v_u1_id uuid;
  v_u2_id uuid;
  v_u1_name text;
  v_u1_avatar text;
  v_u2_name text;
  v_u2_avatar text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT r.rank, r.score, r.user_1_id, r.user_2_id
  INTO v_rank, v_score, v_u1_id, v_u2_id
  FROM public.cp_event_rankings r
  WHERE r.party_event_id = p_event_id
    AND r.period_key = 'current'
    AND (r.user_1_id = v_uid OR r.user_2_id = v_uid)
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT c.user1_id, c.user2_id
    INTO v_u1_id, v_u2_id
    FROM public.couples c
    WHERE c.user1_id = v_uid OR c.user2_id = v_uid
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN NULL;
    END IF;

    v_rank := NULL;
    v_score := 0;
  END IF;

  SELECT username, avatar_url INTO v_u1_name, v_u1_avatar
  FROM public.users WHERE id = v_u1_id;
  SELECT username, avatar_url INTO v_u2_name, v_u2_avatar
  FROM public.users WHERE id = v_u2_id;

  RETURN jsonb_build_object(
    'rank', v_rank,
    'score', COALESCE(v_score, 0),
    'user_1_id', v_u1_id,
    'user_2_id', v_u2_id,
    'user1_name', v_u1_name,
    'user1_avatar', v_u1_avatar,
    'user2_name', v_u2_name,
    'user2_avatar', v_u2_avatar
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_cp_event_rank(uuid) TO anon, authenticated, service_role;
