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
  "20250710150000_cp_event_rankings.sql",
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
    const sql = readFileSync(migrationPath, "utf8");
    await client.query(sql);
    console.log("Applied:", migrationPath);
    const check = await client.query("SELECT to_regclass('public.cp_event_rankings') AS tbl");
    console.log("cp_event_rankings:", check.rows[0]?.tbl);
    const fns = await client.query(
      `\n      SELECT proname FROM pg_proc\n      WHERE proname IN (\n        'refresh_cp_event_rankings',\n        'get_cp_event_gift_top',\n        'get_cp_event_weekly_snapshots',\n        'get_my_cp_event_rank'\n      )\n      ORDER BY proname\n    `,
    );
    console.log("RPCs:", fns.rows.map((r) => r.proname).join(", "));
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
