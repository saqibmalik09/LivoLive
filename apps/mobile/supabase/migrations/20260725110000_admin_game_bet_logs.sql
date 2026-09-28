-- Indexes for admin Games Logs lazy scroll + user filter
CREATE INDEX IF NOT EXISTS game_bets_created_at_id_idx
  ON public.game_bets (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS game_bets_user_created_idx
  ON public.game_bets (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS game_rounds_game_id_created_idx
  ON public.game_rounds (game_id, created_at DESC);

-- Cursor-paged bet log for Official Admin (service role / SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.admin_list_game_bet_logs(
  p_game_slug text DEFAULT NULL,
  p_outcome text DEFAULT NULL, -- all | win | loss
  p_user_q text DEFAULT NULL,
  p_from timestamptz DEFAULT NULL,
  p_to timestamptz DEFAULT NULL,
  p_min_stake bigint DEFAULT NULL,
  p_round_number bigint DEFAULT NULL,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_limit int DEFAULT 40
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_limit int := LEAST(GREATEST(COALESCE(p_limit, 40), 1), 100);
  v_user_ids uuid[];
  v_game_id uuid;
  v_result json;
BEGIN
  IF NULLIF(btrim(p_game_slug), '') IS NOT NULL THEN
    SELECT id INTO v_game_id FROM public.game_configs WHERE slug = btrim(p_game_slug) LIMIT 1;
  END IF;

  IF NULLIF(btrim(p_user_q), '') IS NOT NULL THEN
    SELECT array_agg(u.id) INTO v_user_ids
    FROM public.users u
    WHERE u.username ILIKE '%' || btrim(p_user_q) || '%'
       OR u.short_id::text = btrim(p_user_q)
       OR u.id::text = btrim(p_user_q);
    IF v_user_ids IS NULL THEN
      RETURN json_build_object('rows', '[]'::json, 'has_more', false);
    END IF;
  END IF;

  WITH page_rows AS (
    SELECT
      b.id,
      b.user_id,
      b.round_id,
      b.bet_option,
      b.amount,
      b.payout_amount,
      b.is_win,
      b.is_processed,
      b.created_at,
      u.username,
      u.short_id,
      u.coins AS balance_coins,
      r.round_number,
      r.winner_result,
      r.status AS round_status,
      c.id AS game_id,
      c.slug AS game_slug,
      c.name AS game_name
    FROM public.game_bets b
    JOIN public.users u ON u.id = b.user_id
    JOIN public.game_rounds r ON r.id = b.round_id
    JOIN public.game_configs c ON c.id = r.game_id
    WHERE (v_game_id IS NULL OR r.game_id = v_game_id)
      AND (v_user_ids IS NULL OR b.user_id = ANY (v_user_ids))
      AND (p_from IS NULL OR b.created_at >= p_from)
      AND (p_to IS NULL OR b.created_at < p_to)
      AND (p_min_stake IS NULL OR b.amount >= p_min_stake)
      AND (p_round_number IS NULL OR r.round_number = p_round_number)
      AND (
        p_outcome IS NULL
        OR p_outcome = 'all'
        OR (p_outcome = 'win' AND b.is_win = true)
        OR (p_outcome = 'loss' AND b.is_win = false)
      )
      AND (
        p_cursor_created_at IS NULL
        OR b.created_at < p_cursor_created_at
        OR (b.created_at = p_cursor_created_at AND p_cursor_id IS NOT NULL AND b.id < p_cursor_id)
      )
    ORDER BY b.created_at DESC, b.id DESC
    LIMIT v_limit + 1
  )
  SELECT json_build_object(
    'rows', COALESCE((
      SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC, t.id DESC)
      FROM (SELECT * FROM page_rows LIMIT v_limit) t
    ), '[]'::json),
    'has_more', (SELECT count(*)::int FROM page_rows) > v_limit
  ) INTO v_result;

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_game_bet_logs_summary(
  p_game_slug text DEFAULT NULL,
  p_outcome text DEFAULT NULL,
  p_user_q text DEFAULT NULL,
  p_from timestamptz DEFAULT NULL,
  p_to timestamptz DEFAULT NULL,
  p_min_stake bigint DEFAULT NULL,
  p_round_number bigint DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_ids uuid[];
  v_game_id uuid;
BEGIN
  IF NULLIF(btrim(p_game_slug), '') IS NOT NULL THEN
    SELECT id INTO v_game_id FROM public.game_configs WHERE slug = btrim(p_game_slug) LIMIT 1;
  END IF;

  IF NULLIF(btrim(p_user_q), '') IS NOT NULL THEN
    SELECT array_agg(u.id) INTO v_user_ids
    FROM public.users u
    WHERE u.username ILIKE '%' || btrim(p_user_q) || '%'
       OR u.short_id::text = btrim(p_user_q)
       OR u.id::text = btrim(p_user_q);
    IF v_user_ids IS NULL THEN
      RETURN json_build_object(
        'total_stake', 0,
        'total_payout', 0,
        'net', 0,
        'win_count', 0,
        'loss_count', 0,
        'unique_players', 0,
        'by_game', '[]'::json,
        'wins_by_user', '{}'::json
      );
    END IF;
  END IF;

  RETURN (
    WITH filtered AS (
      SELECT
        b.user_id,
        b.amount,
        b.payout_amount,
        b.is_win,
        c.slug AS game_slug,
        c.name AS game_name
      FROM public.game_bets b
      JOIN public.game_rounds r ON r.id = b.round_id
      JOIN public.game_configs c ON c.id = r.game_id
      WHERE (v_game_id IS NULL OR r.game_id = v_game_id)
        AND (v_user_ids IS NULL OR b.user_id = ANY (v_user_ids))
        AND (p_from IS NULL OR b.created_at >= p_from)
        AND (p_to IS NULL OR b.created_at < p_to)
        AND (p_min_stake IS NULL OR b.amount >= p_min_stake)
        AND (p_round_number IS NULL OR r.round_number = p_round_number)
        AND (
          p_outcome IS NULL
          OR p_outcome = 'all'
          OR (p_outcome = 'win' AND b.is_win = true)
          OR (p_outcome = 'loss' AND b.is_win = false)
        )
    ),
    totals AS (
      SELECT
        COALESCE(sum(amount), 0)::bigint AS total_stake,
        COALESCE(sum(payout_amount), 0)::bigint AS total_payout,
        COALESCE(sum(CASE WHEN is_win THEN 1 ELSE 0 END), 0)::int AS win_count,
        COALESCE(sum(CASE WHEN NOT is_win THEN 1 ELSE 0 END), 0)::int AS loss_count,
        count(DISTINCT user_id)::int AS unique_players
      FROM filtered
    ),
    by_game AS (
      SELECT
        game_slug,
        game_name,
        COALESCE(sum(amount), 0)::bigint AS stake,
        COALESCE(sum(payout_amount), 0)::bigint AS payout,
        count(*)::int AS bets
      FROM filtered
      GROUP BY game_slug, game_name
      ORDER BY stake DESC
    ),
    wins_by_user AS (
      SELECT user_id, COALESCE(sum(payout_amount), 0)::bigint AS win_payout
      FROM filtered
      WHERE is_win = true
      GROUP BY user_id
    ),
    by_user AS (
      SELECT
        f.user_id,
        u.username,
        u.short_id,
        u.coins AS balance_coins,
        COALESCE(sum(f.amount), 0)::bigint AS stake,
        COALESCE(sum(f.payout_amount), 0)::bigint AS payout,
        COALESCE(sum(CASE WHEN f.is_win THEN 1 ELSE 0 END), 0)::int AS wins,
        COALESCE(sum(CASE WHEN NOT f.is_win THEN 1 ELSE 0 END), 0)::int AS losses,
        count(*)::int AS bets
      FROM filtered f
      JOIN public.users u ON u.id = f.user_id
      GROUP BY f.user_id, u.username, u.short_id, u.coins
      ORDER BY stake DESC
      LIMIT 50
    )
    SELECT json_build_object(
      'total_stake', t.total_stake,
      'total_payout', t.total_payout,
      'net', t.total_stake - t.total_payout,
      'win_count', t.win_count,
      'loss_count', t.loss_count,
      'unique_players', t.unique_players,
      'by_game', COALESCE((SELECT json_agg(row_to_json(g)) FROM by_game g), '[]'::json),
      'by_user', COALESCE((SELECT json_agg(row_to_json(bu)) FROM by_user bu), '[]'::json),
      'wins_by_user', COALESCE((
        SELECT json_object_agg(user_id::text, win_payout) FROM wins_by_user
      ), '{}'::json)
    )
    FROM totals t
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_list_game_bet_logs(
  text, text, text, timestamptz, timestamptz, bigint, bigint, timestamptz, uuid, int
) TO service_role;

GRANT EXECUTE ON FUNCTION public.admin_game_bet_logs_summary(
  text, text, text, timestamptz, timestamptz, bigint, bigint
) TO service_role;
