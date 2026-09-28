import { createClient } from "@supabase/supabase-js";

import { readFileSync, existsSync, readdirSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

import pg from "pg";

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const assetsDir = join(adminRoot, "..", "asstes");

const envPath = join(adminRoot, ".env.local");

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

async function main() {
  const env = loadEnv();
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  const dbUrl = env.DATABASE_URL;
  if (!url || !key) throw new Error("Supabase URL / service role missing");
  if (!dbUrl) throw new Error("DATABASE_URL missing");
  if (!existsSync(assetsDir)) throw new Error(`Assets folder missing: ${assetsDir}`);
  const supabase = createClient(url, key);
  const client = new pg.Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const mig = readFileSync(
    join(
      adminRoot,
      "..",
      "sklive-mobile",
      "supabase",
      "migrations",
      "20260719200000_special_id_styles.sql",
    ),
    "utf8",
  );
  await client.query(mig);
  console.log("Migration applied");
  const files = readdirSync(assetsDir)
    .filter((f) => /^beaver_uid_good_number_lv_\d+\.svga$/i.test(f))
    .sort();
  if (files.length === 0) throw new Error("No beaver_uid_good_number_lv_*.svga files found");
  const categoryId = "6ea29ac2-b344-43c3-b356-a3848ea88ad2";
  for (const file of files) {
    const level = Number(file.match(/lv_(\d+)/i)?.[1]);
    if (!level || level < 1 || level > 9) continue;
    const localPath = join(assetsDir, file);
    const buffer = readFileSync(localPath);
    const storagePath = `special-id/beaver_uid_good_number_lv_${level}.svga`;
    const { error: upErr } = await supabase.storage.from("app_assets").upload(storagePath, buffer, {
      contentType: "application/octet-stream",
      upsert: true,
    });
    if (upErr) throw upErr;
    const {
      data: { publicUrl: publicUrl },
    } = supabase.storage.from("app_assets").getPublicUrl(storagePath);
    await client.query(
      `UPDATE public.special_id_styles\n       SET svga_url = $1, updated_at = now()\n       WHERE level = $2`,
      [publicUrl, level],
    );
    const name = `Special ID LV${level}`;
    const existing = await client.query(
      `SELECT id FROM shop_items\n       WHERE category_id = $1 AND name = $2\n       LIMIT 1`,
      [categoryId, name],
    );
    if (existing.rowCount) {
      await client.query(
        `UPDATE shop_items\n         SET svga_url = $1, image_url = COALESCE(NULLIF(image_url, ''), $1),\n             is_for_sale = false, is_active = true, source_type = 'special_id'\n         WHERE id = $2`,
        [publicUrl, existing.rows[0].id],
      );
    } else {
      await client.query(
        `INSERT INTO shop_items (\n           category_id, name, description, price_coins, duration_days,\n           image_url, svga_url, is_active, is_for_sale, source_type\n         ) VALUES (\n           $1, $2, $3, 0, 0, $4, $4, true, false, 'special_id'\n         )`,
        [categoryId, name, `Good number UID bubble style level ${level}`, publicUrl],
      );
    }
    console.log(`LV${level} -> ${publicUrl}`);
  }
  const check = await client.query(
    `SELECT level, name, left(svga_url, 80) AS svga FROM special_id_styles ORDER BY level`,
  );
  console.log("Styles:", check.rows);
  await client.end();
  console.log("Done");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
