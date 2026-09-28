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
  "sk_live",
  "supabase",
  "migrations",
  "20250712170000_room_reward_giftbox.sql",
);

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
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL or SUPABASE_DB_URL required in .env.local");
  }
  const sql = readFileSync(migrationPath, "utf8");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    await client.query(sql);
    const levels = await client.query(
      `SELECT level, required_points FROM public.room_reward_levels ORDER BY level`,
    );
    console.log("Room reward giftbox migration applied.", levels.rows);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
