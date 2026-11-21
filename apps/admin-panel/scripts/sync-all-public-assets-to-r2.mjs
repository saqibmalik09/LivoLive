/**
 * Full backfill: copy EVERY public Supabase storage bucket onto R2/CDN.
 *
 * R2 key layout (matches MediaUrlUtil):
 *   shop_assets/<path>     →  <path>
 *   <any-other-bucket>/x   →  <bucket>/x
 *
 * Never syncs private `real_name_kyc` (PII) unless --include-private-kyc
 * (do not use that flag in production).
 *
 * Usage on VPS (/home/sklive/cdn-sync):
 *   node sync-all-public-assets-to-r2.mjs
 *   node sync-all-public-assets-to-r2.mjs --buckets=profiles,chat_assets
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
function loadEnvFile(path) {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (!m || process.env[m[1]]) continue;
    process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}
loadEnvFile(resolve(__dirname, "../.env.local"));
loadEnvFile(resolve(__dirname, "../.env"));
loadEnvFile(resolve(__dirname, ".env"));

const SUPABASE_URL = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").replace(
  /\/$/,
  "",
);
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID || "";
const CF_TOKEN = process.env.CLOUDFLARE_API_TOKEN || "";
const BUCKET = process.env.R2_BUCKET || "sklive-shop-assets";
const CDN_BASE = (process.env.R2_PUBLIC_BASE_URL || "").replace(/\/$/, "");
const CONCURRENCY = Number(process.env.R2_SYNC_CONCURRENCY || 6);

const NEVER_BY_DEFAULT = new Set(["real_name_kyc"]);

if (!SUPABASE_URL || !SERVICE_KEY || !ACCOUNT_ID || !CF_TOKEN || !CDN_BASE) {
  console.error("Missing env (SUPABASE / Cloudflare R2 / R2_PUBLIC_BASE_URL)");
  process.exit(1);
}

const authHeaders = {
  Authorization: `Bearer ${SERVICE_KEY}`,
  apikey: SERVICE_KEY,
};

function encodeObjectKey(key) {
  return key
    .replace(/^\//, "")
    .split("/")
    .map((s) => encodeURIComponent(s))
    .join("/");
}

function contentTypeFor(path) {
  const lower = path.toLowerCase();
  if (lower.endsWith(".svga")) return "application/octet-stream";
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".gif")) return "image/gif";
  if (lower.endsWith(".mp3")) return "audio/mpeg";
  if (lower.endsWith(".mp4")) return "video/mp4";
  if (lower.endsWith(".apk")) return "application/vnd.android.package-archive";
  if (lower.endsWith(".ipa")) return "application/octet-stream";
  if (lower.endsWith(".html")) return "text/html; charset=utf-8";
  if (lower.endsWith(".svg")) return "image/svg+xml";
  if (lower.endsWith(".json")) return "application/json";
  return "application/octet-stream";
}

function toR2Key(bucket, objectPath) {
  if (bucket === "shop_assets") return objectPath;
  return `${bucket}/${objectPath}`;
}

async function headCdn(r2Key) {
  const url = `${CDN_BASE}/${encodeObjectKey(r2Key)}`;
  try {
    const res = await fetch(url, { method: "HEAD" });
    return res.ok;
  } catch {
    return false;
  }
}

async function uploadToR2(r2Key, body, contentType) {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/r2/buckets/${BUCKET}/objects/${encodeObjectKey(r2Key)}`,
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

async function listAllBuckets() {
  const res = await fetch(`${SUPABASE_URL}/storage/v1/bucket`, {
    headers: authHeaders,
  });
  if (!res.ok) {
    throw new Error(`bucket list ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function listFolder(bucket, prefix, offset, limit) {
  const res = await fetch(`${SUPABASE_URL}/storage/v1/object/list/${encodeURIComponent(bucket)}`, {
    method: "POST",
    headers: {
      ...authHeaders,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      prefix: prefix ? `${prefix}/` : "",
      limit,
      offset,
      sortBy: { column: "name", order: "asc" },
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`list ${bucket}/${prefix}: ${res.status} ${text}`);
  }
  return res.json();
}

async function listBucketObjects(bucket) {
  const files = [];
  async function walk(prefix = "") {
    let offset = 0;
    const limit = 1000;
    for (;;) {
      const rows = await listFolder(bucket, prefix, offset, limit);
      if (!Array.isArray(rows)) {
        throw new Error(`unexpected list response for ${bucket}/${prefix}`);
      }
      for (const item of rows) {
        const name = item.name;
        if (!name || name === ".emptyFolderPlaceholder") continue;
        const path = prefix ? `${prefix}/${name}` : name;
        const isFolder = item.id == null || item.metadata == null;
        if (isFolder) {
          await walk(path);
        } else {
          files.push(path);
        }
      }
      if (rows.length < limit) break;
      offset += limit;
    }
  }
  await walk("");
  return [...new Set(files)];
}

async function downloadObject(bucket, objectPath) {
  const res = await fetch(
    `${SUPABASE_URL}/storage/v1/object/${encodeURIComponent(bucket)}/${encodeObjectKey(objectPath)}`,
    { headers: authHeaders },
  );
  if (!res.ok) {
    throw new Error(`download ${res.status}`);
  }
  return Buffer.from(await res.arrayBuffer());
}

async function mapPool(items, limit, fn) {
  let i = 0;
  const workers = Array.from(
    { length: Math.min(limit, Math.max(items.length, 1)) },
    async () => {
      while (i < items.length) {
        const idx = i++;
        await fn(items[idx], idx);
      }
    },
  );
  await Promise.all(workers);
}

function parseBucketsArg(allPublicNames) {
  const arg = process.argv.find((a) => a.startsWith("--buckets="));
  if (!arg) return allPublicNames;
  return arg
    .slice("--buckets=".length)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

async function syncBucket(bucket) {
  console.log(`\n===== ${bucket} =====`);
  const objects = await listBucketObjects(bucket);
  console.log(`[list] ${objects.length} object(s)`);

  let uploaded = 0;
  let skipped = 0;
  let failed = 0;

  await mapPool(objects, CONCURRENCY, async (objectPath) => {
    const r2Key = toR2Key(bucket, objectPath);
    try {
      if (await headCdn(r2Key)) {
        skipped++;
        return;
      }
      const buf = await downloadObject(bucket, objectPath);
      if (buf.length === 0) {
        console.warn(`[fail] empty ${bucket}/${objectPath}`);
        failed++;
        return;
      }
      await uploadToR2(r2Key, buf, contentTypeFor(objectPath));
      uploaded++;
      if (uploaded % 25 === 0) {
        console.log(
          `[progress] ${bucket} uploaded=${uploaded} skipped=${skipped} failed=${failed}`,
        );
      }
    } catch (e) {
      console.warn(`[fail] ${r2Key}:`, e.message || e);
      failed++;
    }
  });

  console.log(
    `[done] ${bucket} uploaded=${uploaded} skipped=${skipped} failed=${failed}`,
  );
  return { bucket, total: objects.length, uploaded, skipped, failed };
}

async function main() {
  const includeKyc = process.argv.includes("--include-private-kyc");
  const allBuckets = await listAllBuckets();
  const publicNames = allBuckets
    .filter((b) => b && b.public === true)
    .map((b) => b.name || b.id)
    .filter(Boolean)
    .sort();
  const privateSkipped = allBuckets
    .filter((b) => b && b.public !== true)
    .map((b) => b.name || b.id);

  let buckets = parseBucketsArg(publicNames);
  if (!includeKyc) {
    buckets = buckets.filter((b) => !NEVER_BY_DEFAULT.has(b));
  }

  console.log(`CDN=${CDN_BASE}`);
  console.log(`R2 bucket=${BUCKET}`);
  console.log(`Public buckets available: ${publicNames.join(", ")}`);
  if (privateSkipped.length) {
    console.log(
      `Private (skipped by default): ${privateSkipped.join(", ")}`,
    );
  }
  console.log(`Syncing NOW: ${buckets.join(", ")}`);
  console.log(`Concurrency=${CONCURRENCY}`);
  console.log(`started_at=${new Date().toISOString()}`);

  const summaries = [];
  for (const bucket of buckets) {
    try {
      summaries.push(await syncBucket(bucket));
    } catch (e) {
      console.error(`[bucket-fail] ${bucket}:`, e.message || e);
      summaries.push({
        bucket,
        total: 0,
        uploaded: 0,
        skipped: 0,
        failed: 1,
      });
    }
  }

  console.log("\n========== SUMMARY ==========");
  let u = 0;
  let s = 0;
  let f = 0;
  let t = 0;
  for (const row of summaries) {
    console.log(
      `${row.bucket}: total=${row.total} uploaded=${row.uploaded} skipped=${row.skipped} failed=${row.failed}`,
    );
    u += row.uploaded;
    s += row.skipped;
    f += row.failed;
    t += row.total;
  }
  console.log(`ALL: objects=${t} uploaded=${u} skipped=${s} failed=${f}`);
  console.log(`finished_at=${new Date().toISOString()}`);
  if (f > 0) process.exitCode = 2;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
