import { createClient } from "@supabase/supabase-js";

import sharp from "sharp";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const sourcePath = join(adminRoot, "tmp", "cp-events-source", "cp-events-banner.png");

const envPath = join(adminRoot, ".env.local");

const BANNER_WIDTH = 1280;

const BANNER_HEIGHT = 560;

const STORAGE_PATH = "banners/cp-events-v1.jpg";

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

async function main() {
  if (!existsSync(sourcePath)) {
    throw new Error(`Missing banner source: ${sourcePath}`);
  }
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing");
  const supabase = createClient(url, key);
  const buffer = await sharp(readFileSync(sourcePath))
    .resize(BANNER_WIDTH, BANNER_HEIGHT, {
      fit: "cover",
      position: "centre",
    })
    .jpeg({
      quality: 85,
      mozjpeg: true,
    })
    .toBuffer();
  const { error: uploadErr } = await supabase.storage
    .from("app_assets")
    .upload(STORAGE_PATH, buffer, {
      contentType: "image/jpeg",
      upsert: true,
    });
  if (uploadErr) throw uploadErr;
  const {
    data: { publicUrl: publicUrl },
  } = supabase.storage.from("app_assets").getPublicUrl(STORAGE_PATH);
  const { data: existing, error: fetchErr } = await supabase
    .from("party_events")
    .select("id")
    .eq("title", "CP Events")
    .limit(1)
    .maybeSingle();
  if (fetchErr) throw fetchErr;
  const row = {
    title: "CP Events",
    subtitle: "Celebrate love & win rewards",
    banner_url: publicUrl,
    event_kind: "cp_native",
    screen_template: "cp_romance",
    action_type: "none",
    action_config: {
      rules: "Form a CP bond, send couple gifts, and climb the CP leaderboard during this event.",
      rewards: "Exclusive CP frames, bonus coins, and ranking prizes.",
      cta_label: "Open CP Nest",
    },
    is_active: true,
    priority: 10,
    updated_at: new Date().toISOString(),
  };
  if (existing?.id) {
    const { error: error } = await supabase.from("party_events").update(row).eq("id", existing.id);
    if (error) throw error;
    console.log("Updated party_events CP Events:", publicUrl);
  } else {
    const { error: error } = await supabase.from("party_events").insert(row);
    if (error) throw error;
    console.log("Inserted party_events CP Events:", publicUrl);
  }
  console.log("CP Events banner seeded on party_events (1280×560).");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
