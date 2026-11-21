/**
 * Cloudflare R2 uploads via HTTP API (shop_assets CDN source of truth).
 * Env (server-only): CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN,
 * R2_BUCKET, R2_PUBLIC_BASE_URL
 *
 * Raster uploads also write pre-sized WebP thumbs under:
 *   t/w{width}_q{quality}/{originalKeyWithoutExt}.webp
 * so the app can load fast tiles without Supabase /render/image.
 */

import sharp from "sharp";

function required(name: string): string {
  const v = process.env[name]?.trim();
  if (!v) throw new Error(`Missing env ${name} (R2 upload)`);
  return v;
}

/** Widths the mobile app snaps to for gift tiles / general media. */
export const R2_WEBP_WIDTHS = [256, 600, 1200] as const;
/** High quality — small files via WebP, not muddy JPEG. */
export const R2_WEBP_QUALITY = 90;

export function r2PublicBaseUrl(): string {
  return required("R2_PUBLIC_BASE_URL").replace(/\/$/, "");
}

export function r2PublicUrlForKey(key: string): string {
  const clean = key.replace(/^\//, "");
  const encoded = clean
    .split("/")
    .map((s) => encodeURIComponent(s))
    .join("/");
  return `${r2PublicBaseUrl()}/${encoded}`;
}

function encodeObjectKey(key: string): string {
  return key
    .replace(/^\//, "")
    .split("/")
    .map((s) => encodeURIComponent(s))
    .join("/");
}

/** `foo/bar.PNG` → `t/w256_q90/foo/bar.webp` */
export function r2WebpThumbKey(
  originalKey: string,
  width: number,
  quality: number = R2_WEBP_QUALITY,
): string {
  const clean = originalKey.replace(/^\//, "");
  const dot = clean.lastIndexOf(".");
  const stem = dot > 0 ? clean.slice(0, dot) : clean;
  return `t/w${width}_q${quality}/${stem}.webp`;
}

function isRasterContentType(contentType: string, key: string): boolean {
  const ct = contentType.toLowerCase();
  if (ct.startsWith("image/") && !ct.includes("svg")) return true;
  const lower = key.toLowerCase();
  return (
    lower.endsWith(".png") ||
    lower.endsWith(".jpg") ||
    lower.endsWith(".jpeg") ||
    lower.endsWith(".webp") ||
    lower.endsWith(".gif") ||
    lower.endsWith(".jfif") ||
    lower.endsWith(".bmp") ||
    lower.endsWith(".avif")
  );
}

export async function uploadToR2(opts: {
  key: string;
  body: Buffer;
  contentType: string;
}): Promise<{ key: string; publicUrl: string }> {
  const accountId = required("CLOUDFLARE_ACCOUNT_ID");
  const token = required("CLOUDFLARE_API_TOKEN");
  const bucket = process.env.R2_BUCKET?.trim() || "sklive-shop-assets";
  const key = opts.key.replace(/^\//, "");

  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/r2/buckets/${bucket}/objects/${encodeObjectKey(key)}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": opts.contentType || "application/octet-stream",
        "Cache-Control": "public, max-age=31536000, immutable",
      },
      body: new Uint8Array(opts.body),
    },
  );

  const json = (await res.json().catch(() => ({}))) as {
    success?: boolean;
    errors?: { message?: string }[];
  };

  if (!res.ok || json.success === false) {
    const msg =
      json.errors?.map((e) => e.message).filter(Boolean).join("; ") ||
      `${res.status} ${res.statusText}`;
    throw new Error(`R2 upload failed: ${msg}`);
  }

  return { key, publicUrl: r2PublicUrlForKey(key) };
}

/**
 * Upload original bytes, and for rasters also write WebP thumbs (256/600/1200 @ q90).
 * Returns the **original** public URL (DB keeps pointing at the master file).
 */
export async function uploadShopAssetToR2(opts: {
  key: string;
  body: Buffer;
  contentType: string;
}): Promise<{ key: string; publicUrl: string; thumbs: string[] }> {
  const uploaded = await uploadToR2(opts);
  const thumbs: string[] = [];

  if (!isRasterContentType(opts.contentType, opts.key)) {
    return { ...uploaded, thumbs };
  }

  try {
    const pipeline = sharp(opts.body, { failOn: "none" }).rotate();
    for (const width of R2_WEBP_WIDTHS) {
      const webp = await pipeline
        .clone()
        .resize({
          width,
          height: width,
          fit: "inside",
          withoutEnlargement: true,
        })
        .webp({ quality: R2_WEBP_QUALITY, effort: 4 })
        .toBuffer();
      const thumbKey = r2WebpThumbKey(opts.key, width, R2_WEBP_QUALITY);
      const t = await uploadToR2({
        key: thumbKey,
        body: webp,
        contentType: "image/webp",
      });
      thumbs.push(t.publicUrl);
    }
  } catch (e) {
    console.error("[r2] webp thumb generation failed (original kept):", e);
  }

  return { ...uploaded, thumbs };
}

/**
 * Maps a logical Supabase public bucket + object path → R2 key.
 * - shop_assets: bare path (existing shop CDN layout)
 * - everything else: `bucket/path` (matches MediaUrlUtil rewrite)
 */
export function r2KeyForPublicBucket(bucket: string, objectPath: string): string {
  const path = objectPath.replace(/^\//, "");
  if (bucket === "shop_assets") return path;
  return `${bucket}/${path}`;
}

/** Upload to R2 and return the CDN public URL (source of truth for new public media). */
export async function uploadPublicBucketToR2(opts: {
  bucket: string;
  objectPath: string;
  body: Buffer;
  contentType: string;
}): Promise<{ key: string; publicUrl: string; thumbs: string[] }> {
  const key = r2KeyForPublicBucket(opts.bucket, opts.objectPath);
  return uploadShopAssetToR2({
    key,
    body: opts.body,
    contentType: opts.contentType,
  });
}
