import { createClient } from "@supabase/supabase-js";

import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const apkPath = join(
  adminRoot,
  "..",
  "sklive-mobile",
  "build",
  "app",
  "outputs",
  "flutter-apk",
  "app-release.apk",
);

const MIN_VERSION = "1.1.2";

const STORAGE_BUCKET = "app-releases";

const STORAGE_OBJECT = "app-release.apk";

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  const databaseUrl = env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!url || !key)
    throw new Error("NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY required");
  if (!databaseUrl) throw new Error("DATABASE_URL required");
  if (!existsSync(apkPath)) throw new Error(`APK not found: ${apkPath}`);
  const supabase = createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  console.log("Removing old APK from storage (if any)...");
  const { error: delErr } = await supabase.storage.from(STORAGE_BUCKET).remove([STORAGE_OBJECT]);
  if (delErr) {
    console.warn("Delete warning (may be missing):", delErr.message);
  } else {
    console.log("Old object removed.");
  }
  console.log("Uploading new APK...", apkPath);
  const buffer = readFileSync(apkPath);
  console.log(`Size: ${(buffer.length / (1024 * 1024)).toFixed(1)} MB`);
  const { error: upErr } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(STORAGE_OBJECT, buffer, {
      contentType: "application/vnd.android.package-archive",
      upsert: true,
      cacheControl: "60",
    });
  if (upErr) throw upErr;
  const { data: pub } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(STORAGE_OBJECT);
  const cacheBust = `?v=${MIN_VERSION.replace(/\./g, "")}&t=${Date.now()}`;
  const apkUrl = `${pub.publicUrl}${cacheBust}`;
  console.log("Updating app_versions row...");
  const client = new Client({
    connectionString: databaseUrl,
  });
  await client.connect();
  try {
    const { rows: rows } = await client.query(
      `\n      UPDATE public.app_versions\n      SET\n        min_version = $1,\n        apk_download_url = $2,\n        is_force_update = true,\n        download_url = COALESCE(NULLIF(download_url, ''), 'https://www.skliveparty.online/')\n      WHERE platform = 'android'\n      RETURNING platform, min_version, download_url, apk_download_url, is_force_update;\n      `,
      [MIN_VERSION, apkUrl],
    );
    console.log("Done:", rows[0]);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
