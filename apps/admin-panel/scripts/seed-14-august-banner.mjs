import { createClient } from "@supabase/supabase-js";

import { existsSync, readFileSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const bannerPath = join(adminRoot, "tmp", "14-august-banner", "14-august-1280x560.jpg");

const EVENT_ID = "33cb74e8-2f6d-41c2-b180-ba3b29f35ecf";

const STORAGE_PATH = "party-events/14-august-banner-v1.jpg";

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

async function main() {
  if (!existsSync(bannerPath)) throw new Error(`Missing banner: ${bannerPath}`);
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing");
  const supabase = createClient(url, key);
  const buffer = readFileSync(bannerPath);
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
  const { error: dbErr } = await supabase
    .from("party_events")
    .update({
      banner_url: publicUrl,
      updated_at: new Date().toISOString(),
    })
    .eq("id", EVENT_ID);
  if (dbErr) throw dbErr;
  console.log(
    JSON.stringify(
      {
        event_id: EVENT_ID,
        banner_url: publicUrl,
      },
      null,
      2,
    ),
  );
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
