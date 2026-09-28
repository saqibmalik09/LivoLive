import { createClient } from "@supabase/supabase-js";

import sharp from "sharp";

import { readFileSync, existsSync, mkdirSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const cursorAssets = join(
  adminRoot,
  "..",
  "..",
  "..",
  "Users",
  "SULTAN LAPTOPS",
  ".cursor",
  "projects",
  "g-projects-client-project-SK-live",
  "assets",
);

const flutterDir = join(adminRoot, "..", "sk_live", "assets", "images", "ranking-podium");

const envPath = join(adminRoot, ".env.local");

const slots = [
  {
    key: "room_bg_url",
    file: "podium-room.png",
    local: "room.png",
  },
  {
    key: "agency_bg_url",
    file: "podium-agency.png",
    local: "agency.png",
  },
  {
    key: "charm_bg_url",
    file: "podium-charm.png",
    local: "charm.png",
  },
  {
    key: "wealth_bg_url",
    file: "podium-wealth.png",
    local: "wealth.png",
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

function resolveSource(file, local) {
  const paths = [
    join(flutterDir, local),
    join(cursorAssets, file),
    join(adminRoot, "..", "sk_live", "assets", "images", "ranking-podium", local),
  ];
  for (const p of paths) {
    if (existsSync(p)) return p;
  }
  throw new Error(`Missing source for ${file} (tried ${paths.join(", ")})`);
}

async function main() {
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing");
  mkdirSync(flutterDir, {
    recursive: true,
  });
  const supabase = createClient(url, key);
  const row = {
    id: 1,
    slide_interval_ms: 5e3,
    updated_at: new Date().toISOString(),
  };
  for (const { key: col, file: file, local: local } of slots) {
    const src = resolveSource(file, local);
    const optimized = await sharp(src)
      .resize(720, 190, {
        fit: "cover",
        position: "centre",
      })
      .png({
        quality: 85,
        compressionLevel: 9,
      })
      .toBuffer();
    const localPath = join(flutterDir, local);
    await sharp(optimized).toFile(localPath);
    const storagePath = `ranking-podium/${local.replace(".png", "")}-v1.png`;
    const { error: uploadError } = await supabase.storage
      .from("app_assets")
      .upload(storagePath, optimized, {
        contentType: "image/png",
        upsert: true,
      });
    if (uploadError) throw uploadError;
    const {
      data: { publicUrl: publicUrl },
    } = supabase.storage.from("app_assets").getPublicUrl(storagePath);
    row[col] = publicUrl;
    console.log(`Uploaded ${col}: ${publicUrl}`);
  }
  const { error: error } = await supabase.from("home_ranking_podium_config").upsert(row, {
    onConflict: "id",
  });
  if (error) throw error;
  console.log("home_ranking_podium_config seeded.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
