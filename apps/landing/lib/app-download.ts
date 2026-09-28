const FALLBACK_ANDROID_APK =
  'https://api.skliveparty.online/storage/v1/object/public/app-releases/app-release.apk';

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ||
  'https://api.skliveparty.online';

const SUPABASE_ANON_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4OTM1Njg0MCwiZXhwIjo0OTQ1MDMwNDQwLCJyb2xlIjoiYW5vbiJ9.EWvuDd6qv4UxGNXzWnSWQGNXi9NBrD0Y-_XH3bdJwKM';

/** Convert Google Drive share links to direct download when possible. */
export function toDirectDownloadUrl(raw: string): string {
  const url = raw.trim();
  if (!url) return url;

  if (
    url.includes('drive.google.com/uc?') ||
    url.includes('drive.usercontent.google.com/download')
  ) {
    return url;
  }

  const fileMatch = url.match(/drive\.google\.com\/file\/d\/([^/?#]+)/i);
  if (fileMatch?.[1]) {
    return `https://drive.usercontent.google.com/download?id=${fileMatch[1]}&export=download&confirm=t`;
  }

  if (/drive\.google\.com/i.test(url)) {
    const idMatch = url.match(/[?&]id=([^&#]+)/i);
    if (idMatch?.[1]) {
      return `https://drive.usercontent.google.com/download?id=${idMatch[1]}&export=download&confirm=t`;
    }
  }

  return url;
}

/**
 * APK / Drive URL for the landing page Download button.
 * Prefers `apk_download_url`; falls back to legacy `download_url` only if it looks like a file link.
 */
export async function getAndroidDownloadUrl(): Promise<string> {
  try {
    const endpoint = new URL(`${SUPABASE_URL}/rest/v1/app_versions`);
    endpoint.searchParams.set('platform', 'eq.android');
    endpoint.searchParams.set('select', 'apk_download_url,download_url');
    endpoint.searchParams.set('limit', '1');

    const res = await fetch(endpoint.toString(), {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      },
      next: { revalidate: 60 },
    });

    if (!res.ok) return FALLBACK_ANDROID_APK;

    const rows = (await res.json()) as Array<{
      apk_download_url?: string | null;
      download_url?: string | null;
    }>;
    const row = rows[0];
    const apk = row?.apk_download_url?.trim();
    if (apk) return toDirectDownloadUrl(apk);

    const legacy = row?.download_url?.trim() || '';
    if (
      /drive\.google\.com/i.test(legacy) ||
      /\.apk(\?|$)/i.test(legacy) ||
      /app-releases/i.test(legacy)
    ) {
      return toDirectDownloadUrl(legacy);
    }

    return FALLBACK_ANDROID_APK;
  } catch {
    return FALLBACK_ANDROID_APK;
  }
}
