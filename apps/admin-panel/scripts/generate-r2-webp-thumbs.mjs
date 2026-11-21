#!/usr/bin/env node
/**
 * Backfill R2 WebP thumbs for existing shop_assets images.
 * Layout: t/w{256|600|1200}_q90/{stem}.webp  (matches lib/r2.ts)
 *
 * Usage:
 *   node scripts/generate-r2-webp-thumbs.mjs
 *   node scripts/generate-r2-webp-thumbs.mjs --limit=50
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");

function loadEnv() {
  for (const name of [".env.local", ".env.coolify", ".env"]) {
    const p = resolve(root, name);
    if (!existsSync(p)) continue;
    for (const line of readFileSync(p, "utf8").split("\n")) {
      const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
      if (!m) continue;
      if (!process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  }
}

loadEnv();

const WIDTHS = [256, 600, 1200];
const QUALITY = 90;
const accountId = process.env.CLOUDFLARE_ACCOUNT_ID?.trim();
const token = process.env.CLOUDFLARE_API_TOKEN?.trim();
const bucket = process.env.R2_BUCKET?.trim() || "sklive-shop-assets";
const publicBase = (process.env.R2_PUBLIC_BASE_URL || "").replace(/\/$/, "");
const supabaseUrl = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").replace(/\/$/, "");
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

if (!accountId || !token || !publicBase) {
  console.error("Missing CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN / R2_PUBLIC_BASE_URL");
  process.exit(1);
}

const limitArg = process.argv.find((a) => a.startsWith("--limit="));
const limit = limitArg ? Number(limitArg.split("=")[1]) : 0;

function encodeObjectKey(key) {
  return key
    .replace(/^\//, "")
    .split("/")
    .map(encodeURIComponent)
    .join("/");
}

function thumbKey(originalKey, width) {
  const clean = originalKey.replace(/^\//, "");
  const dot = clean.lastIndexOf(".");
  const stem = dot > 0 ? clean.slice(0, dot) : clean;
  return `t/w${width}_q${QUALITY}/${stem}.webp`;
}

function isRasterKey(key) {
  const lower = key.toLowerCase();
  if (lower.startsWith("t/w")) return false;
  if (lower.endsWith(".svga") || lower.endsWith(".mp3")) return false;
  return (
    lower.endsWith(".png") ||
    lower.endsWith(".jpg") ||
    lower.endsWith(".jpeg") ||
    lower.endsWith(".webp") ||
    lower.endsWith(".gif") ||
    lower.endsWith(".jfif") ||
    lower.endsWith(".bmp") ||
    lower.endsWith(".avif") ||
    lower.endsWith(".jpeg")
  );
}

async function r2Put(key, body, contentType) {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/r2/buckets/${bucket}/objects/${encodeObjectKey(key)}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": contentType,
        "Cache-Control": "public, max-age=31536000, immutable",
      },
      body,
    },
  );
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.success === false) {
    throw new Error(
      json.errors?.map((e) => e.message).filter(Boolean).join("; ") ||
        `${res.status} ${res.statusText}`,
    );
  }
}

async function r2HeadOk(key) {
  const res = await fetch(`${publicBase}/${encodeObjectKey(key)}`, {
    method: "HEAD",
  });
  return res.ok;
}

async function download(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GET ${url} → ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

function keyFromShopUrl(url) {
  const m = String(url).match(/shop_assets\/(.+?)(?:\?|$)/);
  if (m) return decodeURIComponent(m[1]);
  // Already CDN: pub-…/key
  try {
    const u = new URL(url);
    if (publicBase && url.startsWith(publicBase)) {
      return decodeURIComponent(u.pathname.replace(/^\//, ""));
    }
  } catch (_) {}
  return null;
}

async function fetchGiftImageKeys() {
  if (!supabaseUrl || !serviceKey) {
    throw new Error("Need NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY for catalog");
  }
  const res = await fetch(
    `${supabaseUrl}/rest/v1/shop_items?select=image_url&is_gift=eq.true&is_active=eq.true&image_url=not.is.null`,
    {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    },
  );
  if (!res.ok) throw new Error(`catalog ${res.status}`);
  const rows = await res.json();
  const keys = new Set();
  for (const row of rows) {
    const key = keyFromShopUrl(row.image_url);
    if (key && isRasterKey(key)) keys.add(key);
  }
  return [...keys];
}

async function processKey(key) {
  const missing = [];
  for (const w of WIDTHS) {
    const tk = thumbKey(key, w);
    if (!(await r2HeadOk(tk))) missing.push(w);
  }
  if (missing.length === 0) return { key, skipped: true };

  let bytes;
  try {
    bytes = await download(`${publicBase}/${encodeObjectKey(key)}`);
  } catch {
    bytes = await download(
      `${supabaseUrl}/storage/v1/object/public/shop_assets/${encodeObjectKey(key)}`,
    );
  }

  const pipeline = sharp(bytes, { failOn: "none" }).rotate();
  for (const w of missing) {
    const webp = await pipeline
      .clone()
      .resize({
        width: w,
        height: w,
        fit: "inside",
        withoutEnlargement: true,
      })
      .webp({ quality: QUALITY, effort: 4 })
      .toBuffer();
    await r2Put(thumbKey(key, w), webp, "image/webp");
  }
  return { key, skipped: false, made: missing };
}

const keys = await fetchGiftImageKeys();
const work = limit > 0 ? keys.slice(0, limit) : keys;
console.log(`Gift image keys: ${keys.length}, processing: ${work.length}`);

let ok = 0;
let skip = 0;
let fail = 0;
for (let i = 0; i < work.length; i++) {
  const key = work[i];
  try {
    const r = await processKey(key);
    if (r.skipped) {
      skip++;
      console.log(`[${i + 1}/${work.length}] skip ${key}`);
    } else {
      ok++;
      console.log(`[${i + 1}/${work.length}] ok  ${key} → ${r.made.join(",")}`);
    }
  } catch (e) {
    fail++;
    console.error(`[${i + 1}/${work.length}] FAIL ${key}: ${e.message || e}`);
  }
}
console.log(`Done. ok=${ok} skip=${skip} fail=${fail}`);
