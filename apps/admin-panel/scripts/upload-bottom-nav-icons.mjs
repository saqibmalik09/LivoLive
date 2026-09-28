import { createClient } from "@supabase/supabase-js";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const assetsDir = join(adminRoot, "..", "sk_live", "assets", "images");

const envPath = join(adminRoot, ".env.local");

function loadEnv() {
  if (!existsSync(envPath)) {
    throw new Error(`Missing ${envPath}`);
  }
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

const UPLOADS = [
  {
    navKey: "home",
    file: "nav_party.png",
    storageName: "home-icon.png",
  },
  {
    navKey: "party",
    file: "nav_discover.png",
    storageName: "party-icon.png",
  },
  {
    navKey: "message",
    file: "nav_message.png",
    storageName: "message-icon.png",
  },
  {
    navKey: "my",
    file: "nav_my.png",
    storageName: "my-icon.png",
  },
];

async function uploadFile(supabase, localPath, storagePath) {
  const buffer = readFileSync(localPath);
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
  if (!url || !key) throw new Error("Supabase URL or service role key missing in .env.local");
  const supabase = createClient(url, key);
  console.log("Uploading bottom nav icons to app_assets/bottom-nav/ ...");
  for (const item of UPLOADS) {
    const localPath = join(assetsDir, item.file);
    if (!existsSync(localPath)) {
      console.warn(`Skip ${item.navKey}: missing ${localPath}`);
      continue;
    }
    const storagePath = `bottom-nav/${item.storageName}`;
    const publicUrl = await uploadFile(supabase, localPath, storagePath);
    console.log(`  ${item.navKey} -> ${publicUrl}`);
    const { error: error } = await supabase
      .from("bottom_nav_items")
      .update({
        icon_url: publicUrl,
        updated_at: new Date().toISOString(),
      })
      .eq("nav_key", item.navKey);
    if (error) console.warn(`  DB update failed for ${item.navKey}:`, error.message);
  }
  const focusPath = join(assetsDir, "focus.png");
  if (existsSync(focusPath)) {
    const focusUrl = await uploadFile(supabase, focusPath, "bottom-nav/focus-overlay.png");
    console.log(`  focus overlay -> ${focusUrl}`);
    await supabase
      .from("bottom_nav_items")
      .update({
        focus_overlay_url: focusUrl,
        updated_at: new Date().toISOString(),
      })
      .eq("nav_key", "home");
  }
  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
