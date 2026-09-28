-- Split Flutter open-URL vs landing APK download URL.

ALTER TABLE public.app_versions
  ADD COLUMN IF NOT EXISTS apk_download_url text;

COMMENT ON COLUMN public.app_versions.download_url IS
  'URL opened by the Flutter app update button (usually the landing website).';
COMMENT ON COLUMN public.app_versions.apk_download_url IS
  'Direct APK / Google Drive download URL used by the landing page Download button.';

-- If download_url currently looks like a Drive/APK file link, move it to apk_download_url
-- and set download_url to the public landing site.
UPDATE public.app_versions
SET
  apk_download_url = COALESCE(NULLIF(apk_download_url, ''), download_url),
  download_url = 'https://rave-land.vercel.app'
WHERE platform = 'android'
  AND (
    download_url ILIKE '%drive.google.com%'
    OR download_url ILIKE '%drive.usercontent.google.com%'
    OR download_url ILIKE '%.apk%'
    OR download_url ILIKE '%/app-releases/%'
  )
  AND (apk_download_url IS NULL OR apk_download_url = '');
