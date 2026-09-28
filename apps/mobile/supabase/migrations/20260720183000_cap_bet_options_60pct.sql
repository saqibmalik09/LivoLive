-- Cap distinct bet options per user per round to 60% of board.
-- Prevents covering every option (guaranteed win). Same option can still be topped up.
-- 8 options → max 4; 10 options → max 6.

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
  v_status text;
  v_is_active boolean;
  v_game_id uuid;
  v_options jsonb;
  v_option_count int;
  v_max_distinct int := 0;
  v_already_on_option boolean;
  v_distinct_count int;
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

  -- Max distinct options = 60% of board (never all options when board > 1)
  v_option_count := COALESCE(jsonb_array_length(v_options), 0);
  IF v_option_count > 1 THEN
    v_max_distinct := GREATEST(1, (v_option_count * 60) / 100);
    IF v_max_distinct >= v_option_count THEN
      v_max_distinct := v_option_count - 1;
    END IF;

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
          'MAX_OPTIONS: You can bet on at most % of % options this round (60%% cap)',
          v_max_distinct, v_option_count
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END IF;

  SELECT coins INTO v_balance FROM public.users WHERE id = v_user_id FOR UPDATE;
  IF v_balance IS NULL OR v_balance < p_amount THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  UPDATE public.users SET coins = coins - p_amount WHERE id = v_user_id;

  INSERT INTO public.game_bets (round_id, user_id, bet_option, amount)
  VALUES (p_round_id, v_user_id, p_option, p_amount);

  INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
  VALUES (v_user_id, -p_amount, 'coin', 'game_loss', p_round_id);

  RETURN json_build_object(
    'success', true,
    'new_balance', v_balance - p_amount,
    'max_options', v_max_distinct,
    'option_count', v_option_count
  );
END;
$function$;
