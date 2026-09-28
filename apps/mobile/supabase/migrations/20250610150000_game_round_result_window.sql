-- Use full round_ends_at (includes result_duration) before starting next betting round.
-- Previously spinning_ends_at skipped the result window entirely.

CREATE OR REPLACE FUNCTION public.advance_game_rounds()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_round RECORD;
    v_winner text;
    v_next_betting_ends timestamp with time zone;
    v_next_spinning_ends timestamp with time zone;
    v_next_round_ends timestamp with time zone;
BEGIN
    FOR v_round IN SELECT r.*, c.betting_duration, c.spinning_duration, c.result_duration 
                   FROM public.game_rounds r 
                   JOIN public.game_configs c ON r.game_id = c.id 
                   WHERE r.status != 'finished' LOOP
        
        -- A. Betting -> Spinning
        IF v_round.status = 'betting' AND now() >= v_round.betting_ends_at THEN
            v_winner := public.resolve_game_winner(v_round.id);
            UPDATE public.game_rounds SET 
                status = 'spinning', 
                winner_result = v_winner 
            WHERE id = v_round.id;

            UPDATE public.game_bets b
            SET is_win = (b.bet_option = v_winner),
                payout_amount = CASE WHEN b.bet_option = v_winner 
                                     THEN b.amount * (SELECT (config_data->'multipliers'->>b.bet_option)::int 
                                                     FROM public.game_configs WHERE id = v_round.game_id)
                                     ELSE 0 END,
                is_processed = true
            WHERE round_id = v_round.id AND is_processed = false;

            UPDATE public.users u
            SET coins = u.coins + b.payout_amount
            FROM public.game_bets b
            WHERE b.round_id = v_round.id AND b.user_id = u.id AND b.is_win = true AND b.payout_amount > 0;
        
        -- B. Spinning -> Finished (after result window), then next betting round
        ELSIF v_round.status = 'spinning' AND now() >= v_round.round_ends_at THEN
            UPDATE public.game_rounds SET status = 'finished' WHERE id = v_round.id;

            v_next_betting_ends := now() + v_round.betting_duration;
            v_next_spinning_ends := v_next_betting_ends + v_round.spinning_duration;
            v_next_round_ends := v_next_spinning_ends + v_round.result_duration;

            INSERT INTO public.game_rounds (game_id, status, betting_ends_at, spinning_ends_at, round_ends_at)
            VALUES (v_round.game_id, 'betting', v_next_betting_ends, v_next_spinning_ends, v_next_round_ends);
        END IF;
    END LOOP;
END;
$function$;

-- Football: longer spin + result window so wheel animation and winner card are visible.
UPDATE public.game_configs
SET
  spinning_duration = interval '12 seconds',
  result_duration = interval '6 seconds'
WHERE slug = 'football_roulette';
