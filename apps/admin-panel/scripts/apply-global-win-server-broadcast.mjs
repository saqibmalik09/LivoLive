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
  "20260814190000_global_win_server_broadcast.sql",
);

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
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL or SUPABASE_DB_URL required in .env.local");
  }
  if (!existsSync(migrationPath)) {
    throw new Error(`Missing migration: ${migrationPath}`);
  }
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
    await client.query(readFileSync(migrationPath, "utf8"));
    const cols = await client.query(
      `SELECT column_name, data_type, column_default\n         FROM information_schema.columns\n        WHERE table_schema = 'public'\n          AND table_name = 'global_win_announcements'\n          AND column_name = 'server_broadcast'`,
    );
    console.table(cols.rows);
    const realtime = await client.query(
      `SELECT 1 FROM pg_publication_tables\n        WHERE pubname = 'supabase_realtime'\n          AND schemaname = 'public'\n          AND tablename = 'global_win_announcements'`,
    );
    console.log("realtime publication:", realtime.rowCount ? "enabled" : "MISSING");
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
