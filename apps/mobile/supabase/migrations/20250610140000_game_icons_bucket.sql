-- Public bucket for game menu icons (Flutter room toolbar).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('game-icons', 'game-icons', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public read game icons" ON storage.objects;
CREATE POLICY "Public read game icons"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'game-icons');

DROP POLICY IF EXISTS "Bootstrap upload game icons" ON storage.objects;
CREATE POLICY "Bootstrap upload game icons"
  ON storage.objects FOR INSERT
  TO anon, authenticated
  WITH CHECK (bucket_id = 'game-icons');

DROP POLICY IF EXISTS "Bootstrap update game icons" ON storage.objects;
CREATE POLICY "Bootstrap update game icons"
  ON storage.objects FOR UPDATE
  TO anon, authenticated
  USING (bucket_id = 'game-icons');

