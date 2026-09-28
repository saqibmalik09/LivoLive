-- Profile cover photos for Party people feed (max 3 enforced in app).

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS cover_images text[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.users.cover_images IS
  'Up to 3 public profile cover image URLs (Party feed thumbnails).';
