import { createClient } from "@supabase/supabase-js";

import sharp from "sharp";

import { readFileSync, existsSync, mkdirSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const sourceDir = join(adminRoot, "tmp", "home-banners-source");

const optimizedDir = join(adminRoot, "tmp", "home-banners-optimized");

const envPath = join(adminRoot, ".env.local");

const BANNER_WIDTH = 1080;

const BANNER_HEIGHT = 320;

const banners = [
  {
    storagePath: "banners/home-vip-v4.jpg",
    sourceFile: "banner-vip.png",
    title: "VIP Club",
    priority: 3,
    matchImage: "banner_vip",
  },
  {
    storagePath: "banners/home-recharge-v4.jpg",
    sourceFile: "banner-recharge.png",
    title: "Recharge Bonus",
    priority: 2,
    matchImage: "banner_recharge",
  },
  {
    storagePath: "banners/home-event-v4.jpg",
    sourceFile: "banner-event.png",
    title: "Special Event",
    priority: 1,
    matchImage: "banner_event",
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

async function optimizeBanner(sourceFile) {
  const sourcePath = join(sourceDir, sourceFile);
  if (!existsSync(sourcePath)) {
    throw new Error(`Missing source image: ${sourcePath}`);
  }
  mkdirSync(optimizedDir, {
    recursive: true,
  });
  const outPath = join(optimizedDir, sourceFile.replace(/\.png$/, ".jpg"));
  await sharp(sourcePath)
    .resize(BANNER_WIDTH, BANNER_HEIGHT, {
      fit: "cover",
      position: "centre",
    })
    .jpeg({
      quality: 85,
      mozjpeg: true,
    })
    .toFile(outPath);
  const buffer = readFileSync(outPath);
  const meta = await sharp(buffer).metadata();
  console.log(
    `Optimized ${sourceFile} → ${meta.width}x${meta.height} (${(buffer.length / 1024).toFixed(0)} KB)`,
  );
  return buffer;
}

async function uploadBanner(supabase, storagePath, buffer) {
  const { error: error } = await supabase.storage.from("app_assets").upload(storagePath, buffer, {
    contentType: "image/jpeg",
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
  const supabase = createClient(url, key);
  const { data: existing, error: fetchErr } = await supabase
    .from("banners")
    .select("id, image_url, priority")
    .eq("is_active", true)
    .order("priority", {
      ascending: false,
    });
  if (fetchErr) throw fetchErr;
  for (const banner of banners) {
    const buffer = await optimizeBanner(banner.sourceFile);
    const publicUrl = await uploadBanner(supabase, banner.storagePath, buffer);
    const row = existing?.find(
      (r) =>
        r.priority === banner.priority || (r.image_url && r.image_url.includes(banner.matchImage)),
    );
    if (row?.id) {
      const { error: error } = await supabase
        .from("banners")
        .update({
          image_url: publicUrl,
        })
        .eq("id", row.id);
      if (error) throw error;
      console.log(`Updated banner priority ${banner.priority}: ${publicUrl}`);
    } else {
      const { error: error } = await supabase.from("banners").insert({
        image_url: publicUrl,
        priority: banner.priority,
        is_active: true,
        link_url: null,
      });
      if (error) throw error;
      console.log(`Inserted banner priority ${banner.priority}: ${publicUrl}`);
    }
  }
  console.log("Home banners seeded (3 × 1080×320).");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
