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
  "20260809180000_voice_backend_settings.sql",
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
    await client.query(
      `UPDATE public.system_settings\n       SET value = $1, updated_at = now()\n       WHERE key = 'orbit_api_url' AND (value IS NULL OR btrim(value) = '')`,
      ["http://34.89.138.245:3000"],
    );
    await client.query(
      `UPDATE public.system_settings\n       SET value = $1, updated_at = now()\n       WHERE key = 'orbit_livekit_url' AND (value IS NULL OR btrim(value) = '')`,
      ["ws://34.89.138.245:7880"],
    );
    const rows = await client.query(
      `SELECT key, value, left(description, 80) AS description\n       FROM public.system_settings\n       WHERE key IN ('voice_backend', 'orbit_api_url', 'orbit_livekit_url')\n       ORDER BY key`,
    );
    console.log("Voice backend settings migration applied:");
    console.table(rows.rows);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
