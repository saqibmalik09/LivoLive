-- Fix: game wins marked on game_bets but coins not credited to users.
-- Use idempotent per-bet payout + game_win transaction + backfill + cron.

CREATE OR REPLACE FUNCTION public.credit_game_round_wins(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_bet record;
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
  LOOP
    UPDATE public.users
    SET coins = coins + v_bet.payout_amount
    WHERE id = v_bet.user_id;

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
BEGIN
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
    AND b.is_processed = false;

  PERFORM public.credit_game_round_wins(p_round_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.advance_game_rounds()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
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
      -- Late bets placed after betting closed: settle against known winner
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

      INSERT INTO public.game_rounds (
        game_id, status, betting_ends_at, spinning_ends_at, round_ends_at
      ) VALUES (
        v_round.game_id, 'betting',
        v_next_betting_ends, v_next_spinning_ends, v_next_round_ends
      );
    END IF;
  END LOOP;
END;
$function$;

-- Backfill all uncredited winning bets
DO $$
DECLARE
  v_round_id uuid;
BEGIN
  FOR v_round_id IN
    SELECT DISTINCT b.round_id
    FROM public.game_bets b
    WHERE b.is_win = true
      AND COALESCE(b.payout_amount, 0) > 0
      AND NOT EXISTS (
        SELECT 1 FROM public.transactions t
        WHERE t.user_id = b.user_id
          AND t.reference_id = b.id
          AND t.transaction_type = 'game_win'
      )
  LOOP
    PERFORM public.credit_game_round_wins(v_round_id);
  END LOOP;
END $$;

-- Ensure game engine cron exists (rounds were advancing via manual/edge calls only)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

DO $$
DECLARE
  v_job_id bigint;
BEGIN
  FOR v_job_id IN
    SELECT jobid FROM cron.job WHERE jobname = 'advance-game-rounds'
  LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;
END $$;

SELECT cron.schedule(
  'advance-game-rounds',
  '5 seconds',
  $$SELECT public.advance_game_rounds();$$
);

GRANT EXECUTE ON FUNCTION public.credit_game_round_wins(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_game_round_bets(uuid, uuid, text) TO authenticated;
