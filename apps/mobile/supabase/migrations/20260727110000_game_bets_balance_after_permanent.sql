-- Permanent balance snapshot per bet (real users.coins at settle time).
-- Loss: balance after stake deducted (place_game_bet).
-- Win: balance after payout credited (credit_game_round_wins) — overwrites place snapshot.
-- Old rows without balance_after: admin RPC falls back to ledger reconstruct until filled.

ALTER TABLE public.game_bets
  ADD COLUMN IF NOT EXISTS balance_after bigint;

COMMENT ON COLUMN public.game_bets.balance_after IS
  'users.coins immediately after this bet settled (stake deduct on place; overwritten with post-payout balance on win credit)';

CREATE INDEX IF NOT EXISTS transactions_user_coin_created_idx
  ON public.transactions (user_id, created_at)
  WHERE currency_type = 'coin';

CREATE INDEX IF NOT EXISTS transactions_game_win_ref_idx
  ON public.transactions (reference_id)
  WHERE transaction_type = 'game_win';

-- ── place_game_bet: store balance after stake deduct ─────────────────────────
CREATE OR REPLACE FUNCTION public.place_game_bet(
  p_round_id uuid,
  p_option text,
  p_amount bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_balance bigint;
  v_new_balance bigint;
  v_status text;
  v_is_active boolean;
  v_game_id uuid;
  v_options jsonb;
  v_option_count int;
  v_max_distinct int := 0;
  v_already_on_option boolean;
  v_distinct_count int;
  v_leave int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid bet amount');
  END IF;

  IF p_option IS NULL OR length(trim(p_option)) = 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid bet option');
  END IF;

  SELECT r.status, COALESCE(c.is_active, false), r.game_id, c.config_data->'options'
  INTO v_status, v_is_active, v_game_id, v_options
  FROM public.game_rounds r
  JOIN public.game_configs c ON c.id = r.game_id
  WHERE r.id = p_round_id
  FOR UPDATE OF r;

  IF v_status IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Round not found');
  END IF;

  IF NOT v_is_active THEN
    RETURN json_build_object('success', false, 'message', 'This game is currently disabled');
  END IF;

  IF v_status <> 'betting' THEN
    RETURN json_build_object('success', false, 'message', 'Betting closed for this round');
  END IF;

  v_option_count := COALESCE(jsonb_array_length(v_options), 0);
  IF v_option_count > 1 THEN
    IF v_option_count <= 3 THEN
      v_max_distinct := GREATEST(1, v_option_count - 1);
    ELSE
      v_max_distinct := v_option_count - 2;
    END IF;
    v_leave := GREATEST(0, v_option_count - v_max_distinct);

    SELECT EXISTS (
      SELECT 1
      FROM public.game_bets b
      WHERE b.round_id = p_round_id
        AND b.user_id = v_user_id
        AND b.bet_option = p_option
    ) INTO v_already_on_option;

    IF NOT v_already_on_option THEN
      SELECT COUNT(DISTINCT b.bet_option)::int INTO v_distinct_count
      FROM public.game_bets b
      WHERE b.round_id = p_round_id
        AND b.user_id = v_user_id;

      IF v_distinct_count >= v_max_distinct THEN
        RAISE EXCEPTION
          'MAX_OPTIONS: You can bet on at most % of % options this round (leave % uncovered)',
          v_max_distinct, v_option_count, v_leave
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END IF;

  SELECT coins INTO v_balance FROM public.users WHERE id = v_user_id FOR UPDATE;
  IF v_balance IS NULL OR v_balance < p_amount THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  v_new_balance := v_balance - p_amount;
  UPDATE public.users SET coins = v_new_balance WHERE id = v_user_id;

  INSERT INTO public.game_bets (round_id, user_id, bet_option, amount, balance_after)
  VALUES (p_round_id, v_user_id, p_option, p_amount, v_new_balance);

  INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
  VALUES (v_user_id, -p_amount, 'coin', 'game_loss', p_round_id);

  RETURN json_build_object(
    'success', true,
    'new_balance', v_new_balance,
    'max_options', v_max_distinct,
    'option_count', v_option_count
  );
END;
$function$;

-- ── credit_game_round_wins: overwrite with balance after payout ─────────────
CREATE OR REPLACE FUNCTION public.credit_game_round_wins(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_bet record;
  v_new_coins bigint;
BEGIN
  FOR v_bet IN
    SELECT b.id, b.user_id, b.payout_amount
    FROM public.game_bets b
    WHERE b.round_id = p_round_id
      AND b.is_win = true
      AND COALESCE(b.payout_amount, 0) > 0
      AND NOT EXISTS (
        SELECT 1 FROM public.transactions t
        WHERE t.user_id = b.user_id
          AND t.reference_id = b.id
          AND t.transaction_type = 'game_win'
      )
    ORDER BY b.created_at ASC, b.id ASC
  LOOP
    UPDATE public.users
    SET coins = coins + v_bet.payout_amount
    WHERE id = v_bet.user_id
    RETURNING coins INTO v_new_coins;

    UPDATE public.game_bets
    SET balance_after = v_new_coins
    WHERE id = v_bet.id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id, description
    ) VALUES (
      v_bet.user_id,
      v_bet.payout_amount,
      'coin',
      'game_win',
      v_bet.id,
      'Game win'
    );
  END LOOP;
END;
$function$;

-- ── admin logs: permanent balance_after; reconstruct only if NULL (legacy) ───
CREATE OR REPLACE FUNCTION public.admin_list_game_bet_logs(
  p_game_slug text DEFAULT NULL,
  p_outcome text DEFAULT NULL,
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
      COALESCE(
        b.balance_after,
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
        )
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

GRANT EXECUTE ON FUNCTION public.place_game_bet(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.credit_game_round_wins(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_game_bet_logs(
  text, text, text, timestamptz, timestamptz, bigint, bigint, timestamptz, uuid, int
) TO service_role;
