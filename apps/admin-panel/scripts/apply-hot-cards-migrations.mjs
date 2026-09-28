import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const migrationsDir = join(adminRoot, "..", "sk_live", "supabase", "migrations");

const envPath = join(adminRoot, ".env.local");

const migrationFiles = [
  "20250630160000_home_hot_cards_config.sql",
  "20250630161000_game_rankings.sql",
];

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
  const databaseUrl = env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL not set in .env.local");
  }
  const client = new Client({
    connectionString: databaseUrl,
  });
  await client.connect();
  try {
    for (const file of migrationFiles) {
      const path = join(migrationsDir, file);
      if (!existsSync(path)) throw new Error(`Missing migration: ${path}`);
      const sql = readFileSync(path, "utf8");
      await client.query(sql);
      console.log(`Applied: ${file}`);
    }
    console.log("All hot-cards migrations applied.");
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
