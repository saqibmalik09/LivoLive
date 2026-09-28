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
  "20260810100000_room_show_spending.sql",
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
    throw new Error(`Missing migration: ${migrationPath}`);
  }
  const sql = readFileSync(migrationPath, "utf8");
  const client = new Client({
    connectionString: connectionString,
    ssl: connectionString.includes("localhost")
      ? undefined
      : {
          rejectUnauthorized: false,
        },
  });
  await client.connect();
  try {
    await client.query(sql);
    const cols = await client.query(
      `SELECT column_name, data_type, column_default, is_nullable\n       FROM information_schema.columns\n       WHERE table_schema = 'public'\n         AND table_name = 'rooms'\n         AND column_name = 'show_spending'`,
    );
    console.log("show_spending migration applied:");
    console.table(cols.rows);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
