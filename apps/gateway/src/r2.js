function required(name) {
  const v = (process.env[name] || "").trim();
  if (!v) throw new Error(`Missing env ${name} (R2 upload)`);
  return v;
}

function r2PublicBaseUrl() {
  return required("R2_PUBLIC_BASE_URL").replace(/\/$/, "");
}

function encodeObjectKey(key) {
  return String(key)
    .replace(/^\//, "")
    .split("/")
    .map((s) => encodeURIComponent(s))
    .join("/");
}

function r2PublicUrlForKey(key) {
  return `${r2PublicBaseUrl()}/${encodeObjectKey(key)}`;
}

function r2KeyForPublicBucket(bucket, objectPath) {
  const path = String(objectPath || "").replace(/^\//, "");
  if (bucket === "shop_assets") return path;
  return `${bucket}/${path}`;
}

async function uploadToR2({ key, body, contentType }) {
  const accountId = required("CLOUDFLARE_ACCOUNT_ID");
  const token = required("CLOUDFLARE_API_TOKEN");
  const bucket = (process.env.R2_BUCKET || "").trim() || "sklive-shop-assets";
  const cleanKey = String(key).replace(/^\//, "");

  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/r2/buckets/${bucket}/objects/${encodeObjectKey(cleanKey)}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": contentType || "application/octet-stream",
        "Cache-Control": "public, max-age=31536000, immutable",
      },
      body,
    },
  );

  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.success === false) {
    const msg =
      (json.errors || [])
        .map((e) => e && e.message)
        .filter(Boolean)
        .join("; ") || `${res.status} ${res.statusText}`;
    throw new Error(`R2 upload failed: ${msg}`);
  }

  return { key: cleanKey, publicUrl: r2PublicUrlForKey(cleanKey) };
}

async function uploadPublicBucketToR2({ bucket, objectPath, body, contentType }) {
  const key = r2KeyForPublicBucket(bucket, objectPath);
  return uploadToR2({ key, body, contentType });
}

module.exports = {
  uploadToR2,
  uploadPublicBucketToR2,
  r2KeyForPublicBucket,
  r2PublicUrlForKey,
};
