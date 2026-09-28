-- Server-emitted global wins (Tulasi merchant callbacks) have no client to push
-- them through the realtime gateway, so clients must play them from Postgres.
-- The flag lets apps take the DB feed for those rows only, and keeps gift/game
-- wins (already fanned out by the winner's socket) from playing twice.

ALTER TABLE public.global_win_announcements
  ADD COLUMN IF NOT EXISTS server_broadcast boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.global_win_announcements.server_broadcast IS
  'True when the row was inserted server-side (no gateway win:notify emitted).';
