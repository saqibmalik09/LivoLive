-- Optional room ID on banners (rooms.short_id). Tap opens that room in-app.
ALTER TABLE public.banners
  ADD COLUMN IF NOT EXISTS room_number bigint;

COMMENT ON COLUMN public.banners.room_number IS
  'Optional public room ID (rooms.short_id). When set, app opens that room on tap.';
