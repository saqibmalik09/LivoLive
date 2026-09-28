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
  "20250711180000_sk_host_party_kind.sql",
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
    const check = await client.query(
      `\n      SELECT pg_get_constraintdef(oid) AS def\n      FROM pg_constraint\n      WHERE conname = 'party_events_event_kind_check'\n    `,
    );
    console.log("Constraint:", check.rows[0]?.def);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
