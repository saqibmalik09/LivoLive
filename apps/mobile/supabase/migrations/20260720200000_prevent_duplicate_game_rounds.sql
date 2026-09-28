-- Prevent duplicate open rounds per game (cron/worker race).
-- Only insert the next betting round if no other open round exists for that game.

CREATE OR REPLACE FUNCTION public.advance_game_rounds()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_round RECORD;
  v_winner text;
  v_next_betting_ends timestamptz;
  v_next_spinning_ends timestamptz;
  v_next_round_ends timestamptz;
BEGIN
  PERFORM public.teen_patti_advance_rounds();

  FOR v_round IN
    SELECT r.*, c.betting_duration, c.spinning_duration, c.result_duration
    FROM public.game_rounds r
    JOIN public.game_configs c ON r.game_id = c.id
    WHERE r.status <> 'finished'
  LOOP
    IF v_round.status = 'betting' AND now() >= v_round.betting_ends_at THEN
      v_winner := public.resolve_game_winner(v_round.id);
      UPDATE public.game_rounds
      SET status = 'spinning', winner_result = v_winner
      WHERE id = v_round.id;

      PERFORM public.process_game_round_bets(v_round.id, v_round.game_id, v_winner);

      BEGIN
        PERFORM public.accrue_fruit_party_jackpot(v_round.id);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;

    ELSIF v_round.status = 'spinning' AND now() >= v_round.round_ends_at THEN
      IF v_round.winner_result IS NOT NULL THEN
        PERFORM public.process_game_round_bets(
          v_round.id, v_round.game_id, v_round.winner_result
        );
      END IF;

      PERFORM public.credit_game_round_wins(v_round.id);

      UPDATE public.game_rounds SET status = 'finished' WHERE id = v_round.id;

      v_next_betting_ends := now() + v_round.betting_duration;
      v_next_spinning_ends := v_next_betting_ends + v_round.spinning_duration;
      v_next_round_ends := v_next_spinning_ends + v_round.result_duration;

      IF NOT EXISTS (
        SELECT 1 FROM public.game_rounds
        WHERE game_id = v_round.game_id
          AND status <> 'finished'
          AND id <> v_round.id
      ) THEN
        INSERT INTO public.game_rounds (
          game_id, status, betting_ends_at, spinning_ends_at, round_ends_at
        ) VALUES (
          v_round.game_id, 'betting',
          v_next_betting_ends, v_next_spinning_ends, v_next_round_ends
        );
      END IF;
    END IF;
  END LOOP;
END;
$function$;
