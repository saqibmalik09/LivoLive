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
  "20260810110000_buddies_intimacy_system.sql",
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
    const tables = await client.query(
      `SELECT table_name\n       FROM information_schema.tables\n       WHERE table_schema = 'public'\n         AND table_name IN ('user_buddies', 'buddy_invitations')\n       ORDER BY table_name`,
    );
    const fns = await client.query(
      `SELECT proname\n       FROM pg_proc p\n       JOIN pg_namespace n ON n.oid = p.pronamespace\n       WHERE n.nspname = 'public'\n         AND proname IN (\n           'get_user_intimacy',\n           'list_buddy_eligible',\n           'invite_buddy',\n           'respond_buddy_invite',\n           'remove_buddy',\n           'list_user_intimacy_board'\n         )\n       ORDER BY proname`,
    );
    console.log("Buddies migration applied.");
    console.table(tables.rows);
    console.table(fns.rows);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
