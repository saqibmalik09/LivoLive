-- Indexes for rankings refresh aggregations on gift_logs.
-- Production apply: sklive-scripts/apply_gift_logs_ranking_indexes.js (CONCURRENTLY).

CREATE INDEX IF NOT EXISTS gift_logs_receiver_created_idx
  ON public.gift_logs (receiver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS gift_logs_sender_created_idx
  ON public.gift_logs (sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS gift_logs_created_idx
  ON public.gift_logs (created_at DESC);
