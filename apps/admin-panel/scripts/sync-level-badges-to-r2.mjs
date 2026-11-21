/**
 * Copy level_configs.badge_url files (charm/wealth/…) onto R2 under
 * app_assets/<path>. Many rows still point at a dead legacy Supabase host;
 * downloads use api.skliveparty.online.
 *
 * Usage (from sklive-admin):
 *   node scripts/sync-level-badges-to-r2.mjs
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = resolve(__dirname, "../.env.local");
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (!m || process.env[m[1]]) continue;
    process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}

const SUPABASE_URL = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").replace(
  /\/$/,
  "",
);
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID || "";
const CF_TOKEN = process.env.CLOUDFLARE_API_TOKEN || "";
const BUCKET = process.env.R2_BUCKET || "sklive-shop-assets";
const CDN_BASE = (process.env.R2_PUBLIC_BASE_URL || "").replace(/\/$/, "");
const ORIGIN = "https://api.skliveparty.online";

if (!SUPABASE_URL || !SERVICE_KEY || !ACCOUNT_ID || !CF_TOKEN || !CDN_BASE) {
  console.error("Missing env (SUPABASE / Cloudflare R2)");
  process.exit(1);
}

function encodeObjectKey(key) {
  return key
    .replace(/^\//, "")
    .split("/")
    .map((s) => encodeURIComponent(s))
    .join("/");
}

function toOriginDownloadUrl(url) {
  try {
    const u = new URL(url);
    u.protocol = "https:";
    u.host = "api.skliveparty.online";
    return u.toString();
  } catch {
    return url;
  }
}

function originToR2Key(url) {
  const marker = "/storage/v1/object/public/app_assets/";
  const idx = url.indexOf(marker);
  if (idx === -1) return null;
  let key = url.substring(idx + marker.length);
  try {
    key = key.split("/").map(decodeURIComponent).join("/");
  } catch (_) {}
  if (!key) return null;
  return `app_assets/${key}`;
}

async function uploadToR2(key, body, contentType) {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/r2/buckets/${BUCKET}/objects/${encodeObjectKey(key)}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${CF_TOKEN}`,
        "Content-Type": contentType || "application/octet-stream",
        "Cache-Control": "public, max-age=31536000, immutable",
      },
      body,
    },
  );
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.success === false) {
    const msg =
      json.errors?.map((e) => e.message).filter(Boolean).join("; ") ||
      `${res.status} ${res.statusText}`;
    throw new Error(msg);
  }
}

async function headCdn(key) {
  const url = `${CDN_BASE}/${encodeObjectKey(key)}`;
  const res = await fetch(url, { method: "HEAD" });
  return res.ok;
}

function guessContentType(key) {
  const lower = key.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".gif")) return "image/gif";
  return "application/octet-stream";
}

async function main() {
  const listUrl = `${SUPABASE_URL}/rest/v1/level_configs?select=badge_url&badge_url=not.is.null&limit=2000`;
  const listRes = await fetch(listUrl, {
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
    },
  });
  if (!listRes.ok) {
    throw new Error(`list failed: ${listRes.status} ${await listRes.text()}`);
  }
  const rows = await listRes.json();
  const urls = new Set();
  for (const row of rows) {
    const u = (row.badge_url || "").trim();
    if (u) urls.add(u);
  }

  console.log(`Found ${urls.size} unique level badge URLs`);
  let ok = 0;
  let skipped = 0;
  let failed = 0;

  for (const url of urls) {
    const key = originToR2Key(url);
    if (!key) {
      console.warn("skip (not app_assets):", url);
      skipped++;
      continue;
    }
    if (await headCdn(key)) {
      console.log("exists", key);
      skipped++;
      continue;
    }
    try {
      const dlUrl = toOriginDownloadUrl(url);
      const dl = await fetch(dlUrl);
      if (!dl.ok) throw new Error(`download ${dl.status} ${dlUrl}`);
      const buf = Buffer.from(await dl.arrayBuffer());
      const ct = dl.headers.get("content-type") || guessContentType(key);
      await uploadToR2(key, buf, ct);
      console.log(`uploaded ${key} (${buf.length} bytes)`);
      ok++;
    } catch (e) {
      console.error("FAIL", key, e.message || e);
      failed++;
    }
  }

  console.log(`done ok=${ok} skipped=${skipped} failed=${failed}`);
  const sample = [...urls][0];
  const sampleKey = originToR2Key(sample);
  if (sampleKey) {
    const smoke = `${CDN_BASE}/${encodeObjectKey(sampleKey)}`;
    const r = await fetch(smoke, { method: "HEAD" });
    console.log("smoke", r.status, smoke);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
