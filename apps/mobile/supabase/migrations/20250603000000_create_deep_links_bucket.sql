-- Run once in Supabase Dashboard → SQL Editor (fixes "bucket not found")
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'deep_links',
  'deep_links',
  true,
  1048576,
  ARRAY['text/html', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public read deep_links" ON storage.objects;
CREATE POLICY "Public read deep_links"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'deep_links');

DROP POLICY IF EXISTS "Authenticated upload deep_links" ON storage.objects;
CREATE POLICY "Authenticated upload deep_links"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'deep_links');

DROP POLICY IF EXISTS "Authenticated update deep_links" ON storage.objects;
CREATE POLICY "Authenticated update deep_links"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'deep_links');
