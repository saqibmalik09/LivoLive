import { createClient } from "@supabase/supabase-js";

import pg from "pg";

import sharp from "sharp";

import { readFileSync, existsSync, mkdirSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const sourceDir = join(adminRoot, "..", "sk_live", "assets", "images", "hot-cards");

const optimizedDir = join(adminRoot, "tmp", "hot-cards-optimized");

const envPath = join(adminRoot, ".env.local");

const migrationPath = join(
  adminRoot,
  "..",
  "sk_live",
  "supabase",
  "migrations",
  "20250630160000_home_hot_cards_config.sql",
);

const slots = [
  {
    slot: "carousel_1",
    file: "carousel-game.png",
    link: "game",
    width: 720,
    height: 500,
  },
  {
    slot: "carousel_2",
    file: "carousel-cp.png",
    link: "cp",
    width: 720,
    height: 500,
  },
  {
    slot: "carousel_3",
    file: "carousel-charm.png",
    link: "charm",
    width: 720,
    height: 500,
  },
  {
    slot: "party_card",
    file: "party-star.png",
    width: 600,
    height: 280,
  },
  {
    slot: "music_card",
    file: "music.png",
    width: 600,
    height: 280,
  },
];

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
  if (!databaseUrl || !existsSync(migrationPath)) return;
  const sql = readFileSync(migrationPath, "utf8");
  const client = new Client({
    connectionString: databaseUrl,
  });
  await client.connect();
  try {
    await client.query(sql);
    console.log("Migration OK: home_hot_cards_config");
  } finally {
    await client.end();
  }
}

async function optimizeImage({ file: file, width: width, height: height }) {
  const sourcePath = join(sourceDir, file);
  if (!existsSync(sourcePath)) {
    throw new Error(`Missing source image: ${sourcePath}`);
  }
  mkdirSync(optimizedDir, {
    recursive: true,
  });
  const outPath = join(optimizedDir, file);
  await sharp(sourcePath)
    .resize(width, height, {
      fit: "cover",
      position: "centre",
    })
    .png({
      quality: 85,
      compressionLevel: 9,
    })
    .toFile(outPath);
  const buffer = readFileSync(outPath);
  console.log(`Optimized ${file} → ${width}x${height} (${(buffer.length / 1024).toFixed(0)} KB)`);
  return buffer;
}

async function uploadSlot(supabase, slot, buffer) {
  const storagePath = `hot-cards/${slot}-v2.png`;
  const { error: error } = await supabase.storage.from("app_assets").upload(storagePath, buffer, {
    contentType: "image/png",
    upsert: true,
  });
  if (error) throw error;
  const {
    data: { publicUrl: publicUrl },
  } = supabase.storage.from("app_assets").getPublicUrl(storagePath);
  return publicUrl;
}

async function main() {
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing");
  await ensureMigration(env.DATABASE_URL);
  const supabase = createClient(url, key);
  const row = {
    id: 1,
    carousel_interval_ms: 4e3,
    updated_at: new Date().toISOString(),
  };
  for (const item of slots) {
    const buffer = await optimizeImage(item);
    const publicUrl = await uploadSlot(supabase, item.slot, buffer);
    row[`${item.slot}_url`] = publicUrl;
    row[`${item.slot}_media_type`] = "image";
    if (item.link) row[`${item.slot}_link`] = item.link;
    console.log(`Uploaded ${item.slot}: ${publicUrl}`);
  }
  const { error: error } = await supabase.from("home_hot_cards_config").upsert(row, {
    onConflict: "id",
  });
  if (error) throw error;
  console.log("home_hot_cards_config seeded with all 5 slots.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
