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
  "20260815140000_allow_invitee_admin_accept.sql",
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
    const fn = await client.query(
      `SELECT pg_get_functiondef('public.enforce_room_member_role_change()'::regprocedure) AS def`,
    );
    const def = fn.rows[0]?.def ?? "";
    const hasInviteePath = def.includes("ri.status = 'accepted'");
    console.log(
      hasInviteePath
        ? "OK: enforce_room_member_role_change includes invitee accept path"
        : "WARN: invitee accept path not found in function body",
    );
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
