-- Dual-run shadow compare while v2 is live (24–48h ops window).
-- Logs live winner vs what legacy v1 would have picked (no side effects on bank).

CREATE TABLE IF NOT EXISTS public.game_winner_shadow_log (
  id bigserial PRIMARY KEY,
  round_id uuid NOT NULL REFERENCES public.game_rounds(id) ON DELETE CASCADE,
  game_id uuid NOT NULL REFERENCES public.game_configs(id) ON DELETE CASCADE,
  game_slug text,
  live_winner text,
  v1_winner text,
  pool bigint NOT NULL DEFAULT 0,
  payout_live bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS game_winner_shadow_log_created_idx
  ON public.game_winner_shadow_log (created_at DESC);

CREATE INDEX IF NOT EXISTS game_winner_shadow_log_slug_idx
  ON public.game_winner_shadow_log (game_slug, created_at DESC);

ALTER TABLE public.game_winner_shadow_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS game_winner_shadow_log_no_client ON public.game_winner_shadow_log;
CREATE POLICY game_winner_shadow_log_no_client
  ON public.game_winner_shadow_log FOR ALL TO authenticated, anon
  USING (false) WITH CHECK (false);

-- Report helper view: win-rate / realized RTP by multiplier bucket (last 48h).
CREATE OR REPLACE VIEW public.game_rtp_mult_report_48h AS
WITH bets AS (
  SELECT
    c.slug AS game_slug,
    coalesce((c.config_data->'multipliers'->>b.bet_option)::int, 0) AS mult,
    b.amount::numeric AS stake,
    coalesce(b.payout_amount, 0)::numeric AS payout,
    b.is_win
  FROM public.game_bets b
  JOIN public.game_rounds r ON r.id = b.round_id
  JOIN public.game_configs c ON c.id = r.game_id
  WHERE b.created_at >= now() - interval '48 hours'
    AND b.is_processed = true
),
bucketed AS (
  SELECT
    game_slug,
    CASE
      WHEN mult <= 5 THEN '1-5x'
      WHEN mult <= 15 THEN '6-15x'
      WHEN mult <= 45 THEN '16-45x'
      ELSE '46x+'
    END AS mult_bucket,
    stake,
    payout,
    is_win
  FROM bets
)
SELECT
  game_slug,
  mult_bucket,
  count(*)::bigint AS bets,
  count(*) FILTER (WHERE is_win)::bigint AS wins,
  round(100.0 * count(*) FILTER (WHERE is_win) / NULLIF(count(*), 0), 2) AS win_rate_pct,
  sum(stake) AS total_stake,
  sum(payout) AS total_payout,
  round(sum(payout) / NULLIF(sum(stake), 0), 4) AS realized_rtp
FROM bucketed
GROUP BY game_slug, mult_bucket
ORDER BY game_slug, mult_bucket;

COMMENT ON VIEW public.game_rtp_mult_report_48h IS
  'Ops report: win-rate and realized RTP by multiplier bucket for last 48h. SELECT * FROM game_rtp_mult_report_48h;';

COMMENT ON TABLE public.game_winner_shadow_log IS
  'Compare live (v2) winner vs v1 pick. Sample SQL:
   SELECT game_slug,
          count(*) AS rounds,
          count(*) FILTER (WHERE live_winner IS DISTINCT FROM v1_winner) AS disagreed,
          round(avg(payout_live::numeric / NULLIF(pool,0)), 4) AS avg_live_rtp
   FROM game_winner_shadow_log
   WHERE created_at >= now() - interval ''48 hours''
   GROUP BY 1;';

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
  v_use_v2 boolean := true;
  v_tmp text;
  v_shadow text;
  v_pool bigint;
  v_payout_live bigint;
BEGIN
  PERFORM public.teen_patti_advance_rounds();

  FOR v_round IN
    SELECT r.*, c.betting_duration, c.spinning_duration, c.result_duration, c.slug AS game_slug
    FROM public.game_rounds r
    JOIN public.game_configs c ON r.game_id = c.id
    WHERE r.status <> 'finished'
  LOOP
    PERFORM pg_advisory_xact_lock(872014, hashtext(v_round.id::text));

    IF v_round.status = 'betting' AND now() >= v_round.betting_ends_at THEN
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

      -- Shadow: while v2 is live, also record what v1 would pick (monitored games).
      BEGIN
        SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_engine_v2';
        v_use_v2 := true;
        IF v_tmp IS NOT NULL THEN
          v_use_v2 := lower(btrim(v_tmp)) IN ('1', 'true', 'yes', 'on');
        END IF;

        IF v_use_v2
           AND v_round.game_slug IN ('lucky_777', 'car_roulette')
        THEN
          v_shadow := public.resolve_game_winner_v1(v_round.id);

          SELECT coalesce(sum(amount), 0)::bigint INTO v_pool
          FROM public.game_bets
          WHERE round_id = v_round.id;

          SELECT coalesce(sum(b.amount * coalesce((c.config_data->'multipliers'->>b.bet_option)::int, 0)), 0)::bigint
          INTO v_payout_live
          FROM public.game_bets b
          JOIN public.game_configs c ON c.id = v_round.game_id
          WHERE b.round_id = v_round.id
            AND b.bet_option = v_winner;

          INSERT INTO public.game_winner_shadow_log (
            round_id, game_id, game_slug, live_winner, v1_winner, pool, payout_live
          ) VALUES (
            v_round.id, v_round.game_id, v_round.game_slug,
            v_winner, v_shadow, v_pool, coalesce(v_payout_live, 0)
          );
        END IF;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;

      PERFORM public.process_game_round_bets(v_round.id, v_round.game_id, v_winner);

      BEGIN
        PERFORM public.accrue_fruit_party_jackpot(v_round.id);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;

    ELSIF v_round.status = 'spinning' AND now() >= v_round.round_ends_at THEN
      SELECT winner_result INTO v_winner
      FROM public.game_rounds
      WHERE id = v_round.id;

      IF v_winner IS NOT NULL THEN
        PERFORM public.process_game_round_bets(
          v_round.id, v_round.game_id, v_winner
        );
      END IF;

      PERFORM public.credit_game_round_wins(v_round.id);

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

GRANT EXECUTE ON FUNCTION public.advance_game_rounds() TO authenticated, service_role;
