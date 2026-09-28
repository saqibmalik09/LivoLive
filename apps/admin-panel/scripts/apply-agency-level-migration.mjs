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
  "20250710120000_agency_level_system.sql",
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
  if (!connectionString) throw new Error("Set DATABASE_URL in .env.local");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    const check = await client.query("SELECT to_regclass('public.agency_level_configs') AS tbl");
    const already = check.rows[0]?.tbl != null;
    console.log("Before:", already ? "tables exist" : "tables missing");
    const sql = readFileSync(migrationPath, "utf8");
    await client.query(sql);
    console.log("Applied:", migrationPath);
    const configs = await client.query(
      "SELECT COUNT(*)::int AS c FROM public.agency_level_configs",
    );
    const assets = await client.query("SELECT COUNT(*)::int AS c FROM public.agency_level_assets");
    console.log("agency_level_configs rows:", configs.rows[0].c);
    console.log("agency_level_assets rows:", assets.rows[0].c);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
