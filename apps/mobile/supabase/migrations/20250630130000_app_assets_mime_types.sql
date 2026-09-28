-- Widen app_assets MIME types so admin icon uploads are not rejected

UPDATE storage.buckets
SET
  allowed_mime_types = ARRAY[
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/webp',
    'image/gif',
    'image/svg+xml',
    'application/octet-stream'
  ],
  file_size_limit = 10485760
WHERE id = 'app_assets';
