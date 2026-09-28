import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const migrationPath = join(
  adminRoot,
  "..",
  "sklive-mobile",
  "supabase",
  "migrations",
  "20260723170000_lucky_daily_cap_window_reset.sql",
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

async function main() {
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL or SUPABASE_DB_URL required in .env.local");
  }
  if (!existsSync(migrationPath)) {
    throw new Error(`Migration file not found: ${migrationPath}`);
  }
  const sql = readFileSync(migrationPath, "utf8");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    console.log("Applying migration...");
    await client.query(sql);
    console.log("Resetting daily cap windows + clearing gift counters...");
    await client.query(
      `\n      UPDATE public.lucky_gift_config\n      SET daily_cap_window_start = now(), updated_at = now()\n      WHERE id = 1;\n\n      UPDATE public.lucky_pro_gift_config\n      SET daily_cap_window_start = now(), updated_at = now()\n      WHERE id = 1;\n\n      TRUNCATE public.lucky_gift_counters;\n      TRUNCATE public.lucky_gift_sender_counters;\n      TRUNCATE public.lucky_pro_gift_counters;\n      TRUNCATE public.lucky_pro_gift_sender_counters;\n    `,
    );
    const { rows: rows } = await client.query(
      `\n      SELECT\n        'lucky' AS variant,\n        daily_cap_window_start,\n        max_daily_bonus_per_sender\n      FROM public.lucky_gift_config WHERE id = 1\n      UNION ALL\n      SELECT\n        'lucky_pro',\n        daily_cap_window_start,\n        max_daily_bonus_per_sender\n      FROM public.lucky_pro_gift_config WHERE id = 1;\n    `,
    );
    console.log("Done. Config window starts:", rows);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
