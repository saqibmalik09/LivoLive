import { createClient } from "@supabase/supabase-js";

import { readFileSync, existsSync, readdirSync } from "fs";

import { dirname, join, extname, basename } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const DEFAULT_SOURCE = "D:\\gif + webp emojis";

const MIME = {
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
};

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

function parseArgs() {
  const args = process.argv.slice(2);
  let sourceDir = process.env.SOURCE_DIR || DEFAULT_SOURCE;
  let dryRun = false;
  let markPremium = false;
  for (const arg of args) {
    if (arg === "--dry-run") dryRun = true;
    else if (arg === "--premium") markPremium = true;
    else if (arg.startsWith("--source=")) sourceDir = arg.slice("--source=".length);
  }
  return {
    sourceDir: sourceDir,
    dryRun: dryRun,
    markPremium: markPremium,
  };
}

function sanitizeStorageName(filename) {
  return filename
    .replace(/\s+/g, "_")
    .replace(/[()]/g, "")
    .replace(/[^a-zA-Z0-9._-]/g, "_");
}

function emojiNameFromFile(filename) {
  let base = basename(filename, extname(filename));
  base = base.replace(/\s*\(\d+\)\s*$/, "").trim();
  return base.slice(0, 120) || "emoji";
}

function listEmojiFiles(sourceDir) {
  if (!existsSync(sourceDir)) {
    throw new Error(`Source folder not found: ${sourceDir}`);
  }
  const files = readdirSync(sourceDir)
    .filter((f) => {
      const ext = extname(f).toLowerCase();
      return ext === ".gif" || ext === ".webp";
    })
    .sort((a, b) => a.localeCompare(b));
  const seen = new Set();
  const unique = [];
  for (const file of files) {
    const key = emojiNameFromFile(file).toLowerCase();
    if (seen.has(key)) {
      console.warn(`Skip duplicate name: ${file}`);
      continue;
    }
    seen.add(key);
    unique.push(file);
  }
  return unique;
}

async function uploadFile(supabase, localPath, storagePath, contentType) {
  const buffer = readFileSync(localPath);
  let error = (
    await supabase.storage.from("app_assets").upload(storagePath, buffer, {
      contentType: contentType,
      upsert: true,
    })
  ).error;
  if (error && contentType !== "application/octet-stream") {
    error = (
      await supabase.storage.from("app_assets").upload(storagePath, buffer, {
        upsert: true,
      })
    ).error;
  }
  if (error) throw error;
  const {
    data: { publicUrl: publicUrl },
  } = supabase.storage.from("app_assets").getPublicUrl(storagePath);
  return publicUrl;
}

async function main() {
  const { sourceDir: sourceDir, dryRun: dryRun, markPremium: markPremium } = parseArgs();
  const files = listEmojiFiles(sourceDir);
  console.log(`Source: ${sourceDir}`);
  console.log(`Files: ${files.length}${dryRun ? " (dry-run)" : ""}`);
  if (files.length === 0) return;
  if (dryRun) {
    files.slice(0, 5).forEach((f, i) => console.log(`  [${i}] ${f} → ${emojiNameFromFile(f)}`));
    if (files.length > 5) console.log(`  ... and ${files.length - 5} more`);
    return;
  }
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing in .env.local");
  const supabase = createClient(url, key);
  const { data: existingRows, error: listError } = await supabase
    .from("room_mic_emojis")
    .select("name, image_url");
  if (listError) throw listError;
  const existingNames = new Set((existingRows ?? []).map((r) => r.name.toLowerCase()));
  let uploaded = 0;
  let skipped = 0;
  let failed = 0;
  let sortOrder = (existingRows?.length ?? 0) + 1;
  for (const file of files) {
    const name = emojiNameFromFile(file);
    if (existingNames.has(name.toLowerCase())) {
      console.log(`Skip (exists): ${name}`);
      skipped++;
      continue;
    }
    const ext = extname(file).toLowerCase();
    const contentType = MIME[ext] || "application/octet-stream";
    const localPath = join(sourceDir, file);
    const storagePath = `room-emojis/bulk/${Date.now()}-${sanitizeStorageName(file)}`;
    try {
      const publicUrl = await uploadFile(supabase, localPath, storagePath, contentType);
      const { error: insertError } = await supabase.from("room_mic_emojis").insert({
        name: name,
        image_url: publicUrl,
        svga_url: null,
        is_premium: markPremium,
        is_active: true,
        sort_order: sortOrder,
      });
      if (insertError) throw insertError;
      existingNames.add(name.toLowerCase());
      sortOrder++;
      uploaded++;
      console.log(`OK [${uploaded}] ${name}`);
    } catch (err) {
      failed++;
      console.error(`FAIL ${file}:`, err.message ?? err);
    }
  }
  console.log("\nDone.");
  console.log(`Uploaded: ${uploaded}, Skipped: ${skipped}, Failed: ${failed}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
