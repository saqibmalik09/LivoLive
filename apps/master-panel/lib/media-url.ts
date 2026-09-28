/** Legacy storage hosts → Coolify public API (path unchanged). */
const LEGACY_STORAGE_HOSTS: Record<string, string> = {
  "sklive.sin.baas.zuvodev.com": "api.skliveparty.online",
  "pbobnvkscssgfpynmdhl.supabase.co": "api.skliveparty.online",
  "supabasekong-mnq3vesx0syflb0m0bot3oa2.51.222.81.97.sslip.io":
    "api.skliveparty.online",
};

const OBJECT_PATH = "/storage/v1/object/public/";
const RENDER_PATH = "/storage/v1/render/image/public/";

/** Encode each path segment so names like `download_(1).png` work. */
function encodePathname(pathname: string): string {
  return pathname
    .split("/")
    .map((seg) => {
      if (!seg) return seg;
      try {
        return encodeURIComponent(decodeURIComponent(seg));
      } catch {
        return encodeURIComponent(seg);
      }
    })
    .join("/");
}

export function rewriteStorageHost(url: string): string {
  const trimmed = url.trim();
  if (!trimmed) return trimmed;
  try {
    const uri = new URL(trimmed);
    const replacement = LEGACY_STORAGE_HOSTS[uri.hostname.toLowerCase()];
    if (!replacement) return trimmed;
    uri.hostname = replacement;
    uri.protocol = "https:";
    return uri.toString();
  } catch {
    return trimmed;
  }
}

function isSvgaUrl(url: string): boolean {
  try {
    return new URL(url).pathname.toLowerCase().endsWith(".svga");
  } catch {
    return url.toLowerCase().includes(".svga");
  }
}

export function publicMediaUrl(url: string | null | undefined): string {
  if (!url?.trim()) return "";
  const rewritten = rewriteStorageHost(url);
  try {
    const uri = new URL(rewritten);
    uri.pathname = encodePathname(uri.pathname);
    return uri.toString();
  } catch {
    return rewritten;
  }
}

export function storageThumbUrl(
  url: string | null | undefined,
  width = 256,
  quality = 80,
): string {
  const rewritten = publicMediaUrl(url);
  if (!rewritten || isSvgaUrl(rewritten)) return rewritten;
  try {
    const uri = new URL(rewritten);
    const idx = uri.pathname.indexOf(OBJECT_PATH);
    if (idx === -1) return rewritten;
    const rest = uri.pathname.slice(idx + OBJECT_PATH.length);
    // rest is already percent-encoded from publicMediaUrl
    return `${uri.origin}${RENDER_PATH}${rest}?width=${width}&quality=${quality}&format=webp`;
  } catch {
    const idx = rewritten.indexOf(OBJECT_PATH);
    if (idx === -1) return rewritten;
    const base = rewritten.slice(0, idx);
    const rest = rewritten.slice(idx + OBJECT_PATH.length).split("?")[0] ?? "";
    return `${base}${RENDER_PATH}${rest}?width=${width}&quality=${quality}&format=webp`;
  }
}
