/**
 * Public media URLs → Cloudflare CDN (cdn.skliveparty.online).
 * Matches mobile MediaUrlUtil / SupabaseImageTransform layout:
 * - shop_assets/<key> → cdn/<key>
 * - other public buckets → cdn/<bucket>/<key>
 * - never rewrite private real_name_kyc
 */

const LEGACY_STORAGE_HOSTS: Record<string, string> = {
  "sklive.sin.baas.zuvodev.com": "api.skliveparty.online",
  "pbobnvkscssgfpynmdhl.supabase.co": "api.skliveparty.online",
  "wbwvtsnuvenxvetbhupf.supabase.co": "api.skliveparty.online",
  "supabasekong-mnq3vesx0syflb0m0bot3oa2.51.222.81.97.sslip.io":
    "api.skliveparty.online",
};

const OBJECT_PATH = "/storage/v1/object/public/";
const RENDER_PATH = "/storage/v1/render/image/public/";
const LEGACY_R2_DEV_HOST = "pub-80dc1ca1b3fa42ebbe92e1941dfccda2.r2.dev";

function cdnBase(): string {
  const raw =
    (typeof process !== "undefined" &&
      process.env.NEXT_PUBLIC_CDN_BASE_URL?.trim()) ||
    (typeof process !== "undefined" &&
      process.env.R2_PUBLIC_BASE_URL?.trim()) ||
    "https://cdn.skliveparty.online";
  return raw.replace(/\/$/, "");
}

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

/** Origin /storage/v1/object/public/... → CDN URL. */
export function rewritePublicAssetsToCdn(url: string): string {
  const base = cdnBase();
  if (!base) return url;
  try {
    const uri = new URL(url);
    const host = uri.hostname.toLowerCase();

    if (host === LEGACY_R2_DEV_HOST) {
      const path = uri.pathname.replace(/^\//, "");
      return `${base}/${path}`;
    }
    try {
      if (host === new URL(base).hostname.toLowerCase()) return url;
    } catch {
      /* ignore */
    }

    const path = uri.pathname;
    const idx = path.indexOf(OBJECT_PATH);
    if (idx === -1) return url;
    const rest = path.slice(idx + OBJECT_PATH.length);
    if (!rest) return url;
    if (rest.startsWith("real_name_kyc/")) return url;

    if (rest.startsWith("shop_assets/")) {
      const key = rest.slice("shop_assets/".length);
      if (!key) return url;
      return `${base}/${encodePathname(key)}`;
    }

    return `${base}/${encodePathname(rest)}`;
  } catch {
    return url;
  }
}

function isSvgaUrl(url: string): boolean {
  try {
    return new URL(url).pathname.toLowerCase().endsWith(".svga");
  } catch {
    return url.toLowerCase().includes(".svga");
  }
}

function isOurCdnHost(host: string): boolean {
  try {
    return (
      host.toLowerCase() === new URL(cdnBase()).hostname.toLowerCase() ||
      host.toLowerCase() === LEGACY_R2_DEV_HOST
    );
  } catch {
    return false;
  }
}

/** Resolve any stored media URL for display (CDN when public). */
export function publicMediaUrl(url: string | null | undefined): string {
  if (!url?.trim()) return "";
  let rewritten = rewriteStorageHost(url.trim());
  rewritten = rewritePublicAssetsToCdn(rewritten);
  try {
    const uri = new URL(rewritten);
    uri.pathname = encodePathname(uri.pathname);
    return uri.toString();
  } catch {
    return rewritten;
  }
}

/** Thumb: CF image resize on CDN, else origin /render/image. */
export function storageThumbUrl(
  url: string | null | undefined,
  width = 256,
  quality = 80,
): string {
  const rewritten = publicMediaUrl(url);
  if (!rewritten || isSvgaUrl(rewritten)) return rewritten;
  try {
    const uri = new URL(rewritten);
    if (isOurCdnHost(uri.hostname)) {
      let key = uri.pathname.replace(/^\//, "");
      if (key.startsWith("cdn-cgi/image/")) return rewritten;
      if (key.startsWith("t/w")) return rewritten;
      key = key
        .split("/")
        .map((s) => {
          try {
            return decodeURIComponent(s);
          } catch {
            return s;
          }
        })
        .join("/");
      const encoded = encodePathname(key);
      const q = Math.min(100, Math.max(60, quality));
      return `${cdnBase()}/cdn-cgi/image/width=${width},quality=${q},format=auto/${encoded}`;
    }

    const idx = uri.pathname.indexOf(OBJECT_PATH);
    if (idx === -1) return rewritten;
    const rest = uri.pathname.slice(idx + OBJECT_PATH.length);
    return `${uri.origin}${RENDER_PATH}${rest}?width=${width}&quality=${quality}&format=webp`;
  } catch {
    return rewritten;
  }
}
