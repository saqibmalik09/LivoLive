import { createClient } from "@supabase/supabase-js";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const imagesDir = join(adminRoot, "..", "sk_live", "assets", "images");

const envPath = join(adminRoot, ".env.local");

const PODIUM_FRAMES = [
  {
    rank: 1,
    file: "rank_1_frame.png",
  },
  {
    rank: 2,
    file: "rank_2_frame.png",
  },
  {
    rank: 3,
    file: "rank_3_frame.png",
  },
];

const ROOM_CARD_FRAMES = [
  {
    rank: 1,
    file: "rank_frame_1.png",
  },
  {
    rank: 2,
    file: "rank_frame_2.png",
  },
  {
    rank: 3,
    file: "rank_frame_3.png",
  },
];

const PERIODS = ["daily", "weekly", "monthly"];

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

async function uploadFile(supabase, storagePath, buffer) {
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

async function upsertAsset(supabase, category, period, rank, frameUrl) {
  const { data: existing } = await supabase
    .from("ranking_assets")
    .select("id, badge_url")
    .eq("category", category)
    .eq("ranking_type", period)
    .eq("rank_position", rank)
    .maybeSingle();
  const row = {
    category: category,
    ranking_type: period,
    rank_position: rank,
    frame_url: frameUrl,
    badge_url: existing?.badge_url ?? "",
  };
  if (existing?.id) {
    const { error: error } = await supabase
      .from("ranking_assets")
      .update(row)
      .eq("id", existing.id);
    if (error) throw error;
  } else {
    const { error: error } = await supabase.from("ranking_assets").insert(row);
    if (error) throw error;
  }
}

async function main() {
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing");
  const supabase = createClient(url, key);
  const podiumUrls = {};
  for (const { rank: rank, file: file } of PODIUM_FRAMES) {
    const path = join(imagesDir, file);
    if (!existsSync(path)) throw new Error(`Missing ${path}`);
    podiumUrls[rank] = await uploadFile(
      supabase,
      `ranking-assets/podium-rank-${rank}-wing.png`,
      readFileSync(path),
    );
    console.log(`Podium frame ${rank}: ${podiumUrls[rank]}`);
  }
  const roomCardUrls = {};
  for (const { rank: rank, file: file } of ROOM_CARD_FRAMES) {
    const path = join(imagesDir, file);
    const fallback = join(imagesDir, "rank_frame_2.png");
    const usePath = existsSync(path) ? path : fallback;
    if (!existsSync(usePath)) throw new Error(`Missing ${path}`);
    roomCardUrls[rank] = await uploadFile(
      supabase,
      `ranking-assets/room-card-rank-${rank}.png`,
      readFileSync(usePath),
    );
    console.log(`Room card frame ${rank}: ${roomCardUrls[rank]}`);
  }
  for (const period of PERIODS) {
    for (const { rank: rank } of PODIUM_FRAMES) {
      await upsertAsset(supabase, "Podium", period, rank, podiumUrls[rank]);
    }
    for (const { rank: rank } of ROOM_CARD_FRAMES) {
      await upsertAsset(supabase, "Room", period, rank, roomCardUrls[rank]);
    }
    console.log(`Seeded Podium + Room card frames / ${period}`);
  }
  console.log("Done: Podium = wing frames on home ranking cards.");
  console.log("Done: Room = card frames on Top-3 cards + Popular/New grid (top 1–3).");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
