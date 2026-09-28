import pg from "pg";

import { createClient } from "@supabase/supabase-js";

import { readFileSync, existsSync, readdirSync } from "fs";

import { dirname, join, basename } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const folderPath = join(adminRoot, "..", "svga bonus");

const migrationPath = join(
  adminRoot,
  "..",
  "sk_live",
  "supabase",
  "migrations",
  "20250712140000_lucky_bonus_multiplier_svgas.sql",
);

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

function parseMultiplier(filename) {
  const m = basename(filename).match(/beaver_gift_number_(\d+)\.svga$/i);
  return m ? Number(m[1]) : null;
}

async function main() {
  const env = loadEnv();
  const dbUrl = env.DATABASE_URL || env.SUPABASE_DB_URL;
  const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SERVICE_KEY;
  if (!dbUrl) throw new Error("DATABASE_URL missing");
  if (!supabaseUrl || !serviceKey) {
    throw new Error("Supabase URL / service role key missing");
  }
  if (!existsSync(folderPath)) {
    throw new Error(`Missing folder: ${folderPath}`);
  }
  const files = readdirSync(folderPath)
    .filter((f) => f.toLowerCase().endsWith(".svga"))
    .sort((a, b) => (parseMultiplier(a) ?? 0) - (parseMultiplier(b) ?? 0));
  if (files.length === 0) throw new Error("No .svga files in svga bonus");
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  try {
    await client.query(readFileSync(migrationPath, "utf8"));
    console.log("Applied migration");
    for (const file of files) {
      const multiplier = parseMultiplier(file);
      if (!multiplier) {
        console.warn("Skip (no number):", file);
        continue;
      }
      const localPath = join(folderPath, file);
      const storagePath = `lucky-bonus-svga/${file}`;
      const bytes = readFileSync(localPath);
      const { error: upErr } = await supabase.storage
        .from("app_assets")
        .upload(storagePath, bytes, {
          contentType: "application/octet-stream",
          upsert: true,
        });
      if (upErr) throw new Error(`Upload ${file}: ${upErr.message}`);
      const { data: pub } = supabase.storage.from("app_assets").getPublicUrl(storagePath);
      const svgaUrl = pub.publicUrl;
      await client.query(
        `\n        INSERT INTO public.lucky_bonus_multiplier_svgas\n          (multiplier, label, svga_url, is_enabled, applies_to, sort_order, updated_at)\n        VALUES ($1, $2, $3, true, 'both', $1, now())\n        ON CONFLICT (multiplier) DO UPDATE SET\n          label = EXCLUDED.label,\n          svga_url = EXCLUDED.svga_url,\n          updated_at = now()\n        `,
        [multiplier, `x${multiplier}`, svgaUrl],
      );
      console.log(`OK x${multiplier} -> ${svgaUrl}`);
    }
    const rows = await client.query(
      `SELECT multiplier, is_enabled, applies_to, svga_url\n       FROM public.lucky_bonus_multiplier_svgas\n       ORDER BY multiplier`,
    );
    console.log("\nSeeded rows:", rows.rowCount);
    for (const r of rows.rows) {
      console.log(`  x${r.multiplier} enabled=${r.is_enabled} ${r.applies_to}`);
    }
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
