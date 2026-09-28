-- CP Nest gift images (admin uploads via sk-live-admin → cp_nest_assets bucket)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'cp_nest_assets',
  'cp_nest_assets',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

DROP POLICY IF EXISTS "Public read cp_nest_assets" ON storage.objects;
CREATE POLICY "Public read cp_nest_assets"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'cp_nest_assets');
