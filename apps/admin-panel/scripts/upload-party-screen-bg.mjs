import { createClient } from "@supabase/supabase-js";

import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const assetPath = join(adminRoot, "..", "sk_live", "assets", "images", "party-football-bg.png");

const migrationPath = join(
  adminRoot,
  "..",
  "sk_live",
  "supabase",
  "migrations",
  "20250630140000_party_screen_config.sql",
);

const envPath = join(adminRoot, ".env.local");

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

async function ensureMigration(databaseUrl) {
  if (!databaseUrl) {
    console.warn("DATABASE_URL not set — skipping migration (table must exist already).");
    return;
  }
  if (!existsSync(migrationPath)) {
    throw new Error(`Missing migration: ${migrationPath}`);
  }
  const sql = readFileSync(migrationPath, "utf8");
  const client = new Client({
    connectionString: databaseUrl,
  });
  await client.connect();
  try {
    await client.query(sql);
    console.log("Migration applied: 20250630140000_party_screen_config.sql");
  } finally {
    await client.end();
  }
}

async function uploadVariant(supabase, buffer, variant) {
  const fileName = `party-screen/${variant}-${Date.now()}.png`;
  const { error: error } = await supabase.storage.from("app_assets").upload(fileName, buffer, {
    contentType: "image/png",
    upsert: true,
  });
  if (error) throw error;
  const {
    data: { publicUrl: publicUrl },
  } = supabase.storage.from("app_assets").getPublicUrl(fileName);
  return publicUrl;
}

async function main() {
  if (!existsSync(assetPath)) {
    throw new Error(`Missing asset: ${assetPath}`);
  }
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing");
  await ensureMigration(env.DATABASE_URL);
  const supabase = createClient(url, key);
  const buffer = readFileSync(assetPath);
  console.log("Uploading party screen backgrounds from party-football-bg.png ...");
  const topUrl = await uploadVariant(supabase, buffer, "top");
  console.log("  top ->", topUrl);
  const bottomUrl = await uploadVariant(supabase, buffer, "bottom");
  console.log("  bottom ->", bottomUrl);
  const { error: error } = await supabase.from("party_screen_config").upsert(
    {
      id: 1,
      top_image_url: topUrl,
      bottom_image_url: bottomUrl,
      updated_at: new Date().toISOString(),
    },
    {
      onConflict: "id",
    },
  );
  if (error) {
    throw new Error(
      `${error.message}. Run migration 20250630140000_party_screen_config.sql (set DATABASE_URL in .env.local and re-run).`,
    );
  }
  console.log("Done. Replace top/bottom with cropped images in admin when ready.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
