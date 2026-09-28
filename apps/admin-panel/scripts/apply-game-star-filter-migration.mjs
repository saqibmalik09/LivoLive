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
  "20250711160000_game_star_filter_selected_games.sql",
);

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
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
    await client.query(readFileSync(migrationPath, "utf8"));
    console.log("Applied:", migrationPath);
    const fn = await client.query(
      `SELECT proname FROM pg_proc WHERE proname = '_game_star_game_ids'`,
    );
    console.log("helper:", fn.rows.map((r) => r.proname).join(", ") || "(missing)");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
