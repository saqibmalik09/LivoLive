-- Move platform bank balance update to actual settled payouts (M5).
-- Incremental: only newly processed bets contribute (supports late-bet re-settle).

CREATE OR REPLACE FUNCTION public.process_game_round_bets(
  p_round_id uuid,
  p_game_id uuid,
  p_winner text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_new_stake numeric := 0;
  v_new_payout numeric := 0;
  v_target_rtp double precision := 0.90;
  v_tmp text;
BEGIN
  WITH updated AS (
    UPDATE public.game_bets b
    SET is_win = (b.bet_option = p_winner),
        payout_amount = CASE
          WHEN b.bet_option = p_winner THEN b.amount * (
            SELECT (config_data->'multipliers'->>b.bet_option)::int
            FROM public.game_configs
            WHERE id = p_game_id
          )
          ELSE 0
        END,
        is_processed = true
    WHERE b.round_id = p_round_id
      AND b.is_processed = false
    RETURNING b.amount, b.payout_amount
  )
  SELECT
    coalesce(sum(amount), 0)::numeric,
    coalesce(sum(payout_amount), 0)::numeric
  INTO v_new_stake, v_new_payout
  FROM updated;

  IF v_new_stake > 0 OR v_new_payout > 0 THEN
    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_target_rtp';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_target_rtp := GREATEST(0.50, LEAST(0.98, v_tmp::double precision));
    END IF;

    INSERT INTO public.game_platform_bank (game_id)
    VALUES (p_game_id)
    ON CONFLICT (game_id) DO NOTHING;

    UPDATE public.game_platform_bank
    SET
      balance_coins = balance_coins
        + (v_new_stake * v_target_rtp)
        - v_new_payout,
      updated_at = now()
    WHERE game_id = p_game_id;
  END IF;

  PERFORM public.credit_game_round_wins(p_round_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.process_game_round_bets(uuid, uuid, text) TO authenticated, service_role;
