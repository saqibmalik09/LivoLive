-- Allow SVGA uploads to app_assets (ranking frames, hot cards, etc.)

UPDATE storage.buckets
SET
  allowed_mime_types = ARRAY[
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/webp',
    'image/gif',
    'image/svg+xml',
    'application/octet-stream',
    'application/x-svga',
    'video/mp4',
    'video/webm'
  ]::text[],
  file_size_limit = 20971520
WHERE id = 'app_assets';
