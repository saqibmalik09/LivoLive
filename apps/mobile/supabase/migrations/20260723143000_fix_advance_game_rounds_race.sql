-- Fix race: concurrent advance_game_rounds() overwrote winner_result after bets
-- were already processed against a different winner (missed/wrong payouts).
-- Claim status transitions atomically; only the winner of the claim settles.

CREATE OR REPLACE FUNCTION public.advance_game_rounds()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_round RECORD;
  v_winner text;
  v_locked_id uuid;
  v_finished_id uuid;
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
    -- Serialize per-round work across concurrent cron/worker calls.
    PERFORM pg_advisory_xact_lock(872014, hashtext(v_round.id::text));

    IF v_round.status = 'betting' AND now() >= v_round.betting_ends_at THEN
      -- Atomic claim: only one caller may leave betting → spinning.
      UPDATE public.game_rounds
      SET status = 'spinning'
      WHERE id = v_round.id
        AND status = 'betting'
      RETURNING id INTO v_locked_id;

      IF v_locked_id IS NULL THEN
        CONTINUE;
      END IF;

      v_winner := public.resolve_game_winner(v_round.id);

      UPDATE public.game_rounds
      SET winner_result = v_winner
      WHERE id = v_round.id
        AND status = 'spinning';

      PERFORM public.process_game_round_bets(v_round.id, v_round.game_id, v_winner);

      BEGIN
        PERFORM public.accrue_fruit_party_jackpot(v_round.id);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;

    ELSIF v_round.status = 'spinning' AND now() >= v_round.round_ends_at THEN
      -- Re-read winner under lock (may have been set by the claim above).
      SELECT winner_result INTO v_winner
      FROM public.game_rounds
      WHERE id = v_round.id;

      IF v_winner IS NOT NULL THEN
        PERFORM public.process_game_round_bets(
          v_round.id, v_round.game_id, v_winner
        );
      END IF;

      PERFORM public.credit_game_round_wins(v_round.id);

      -- Atomic claim: only one caller may finish the round / spawn next.
      UPDATE public.game_rounds
      SET status = 'finished'
      WHERE id = v_round.id
        AND status = 'spinning'
      RETURNING id INTO v_finished_id;

      IF v_finished_id IS NULL THEN
        CONTINUE;
      END IF;

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
