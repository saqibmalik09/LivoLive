-- Hot-path indexes for game engine lag.
-- advance_game_rounds scans non-finished rounds every ~5s; resolve_game_winner_v2
-- and settle hit game_bets repeatedly by round_id.
--
-- Production apply: use sklive-scripts/apply_game_hot_indexes.js which runs
-- CREATE INDEX CONCURRENTLY outside a transaction. This migration file is the
-- schema record (IF NOT EXISTS) for non-concurrent / fresh environments.

-- Partial: only active rounds (dozens of rows even if table is millions)
CREATE INDEX IF NOT EXISTS game_rounds_active_idx
  ON public.game_rounds (status, betting_ends_at)
  WHERE status <> 'finished';

CREATE INDEX IF NOT EXISTS game_bets_round_option_idx
  ON public.game_bets (round_id, bet_option);

CREATE INDEX IF NOT EXISTS game_bets_round_user_idx
  ON public.game_bets (round_id, user_id);
