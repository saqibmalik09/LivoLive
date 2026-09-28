-- Game Logs: show balance AFTER each bet settled (not current users.coins).
-- Reconstruct: balance_then = current_coins - sum(coin txs after event).
-- Win event  = game_win tx (reference_id = bet.id)
-- Loss event = bet.created_at (stake deducted at place time)

CREATE INDEX IF NOT EXISTS transactions_user_coin_created_idx
  ON public.transactions (user_id, created_at)
  WHERE currency_type = 'coin';

CREATE INDEX IF NOT EXISTS transactions_game_win_ref_idx
  ON public.transactions (reference_id)
  WHERE transaction_type = 'game_win';

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
      (
        u.coins - COALESCE((
          WITH event AS (
            SELECT w.created_at, w.id
            FROM public.transactions w
            WHERE b.is_win = true
              AND w.user_id = b.user_id
              AND w.reference_id = b.id
              AND w.transaction_type = 'game_win'
              AND w.currency_type = 'coin'
            ORDER BY w.created_at ASC, w.id ASC
            LIMIT 1
          )
          SELECT SUM(t.amount)::bigint
          FROM public.transactions t
          LEFT JOIN event e ON true
          WHERE t.user_id = b.user_id
            AND t.currency_type = 'coin'
            AND (
              (
                e.id IS NOT NULL
                AND (
                  t.created_at > e.created_at
                  OR (t.created_at = e.created_at AND t.id > e.id)
                )
              )
              OR (
                e.id IS NULL
                AND t.created_at > b.created_at
              )
            )
        ), 0)
      ) AS balance_coins,
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

GRANT EXECUTE ON FUNCTION public.admin_list_game_bet_logs(
  text, text, text, timestamptz, timestamptz, bigint, bigint, timestamptz, uuid, int
) TO service_role;
