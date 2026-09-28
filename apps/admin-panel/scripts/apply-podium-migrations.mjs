import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const migrationsDir = join(__dirname, "..", "..", "sk_live", "supabase", "migrations");

const envPath = join(__dirname, "..", ".env.local");

const migrationFiles = [
  "20250701120000_home_ranking_podium_config.sql",
  "20250701121000_agency_rankings.sql",
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
  if (!env.DATABASE_URL) throw new Error("DATABASE_URL not set");
  const client = new Client({
    connectionString: env.DATABASE_URL,
  });
  await client.connect();
  try {
    for (const file of migrationFiles) {
      const path = join(migrationsDir, file);
      await client.query(readFileSync(path, "utf8"));
      console.log(`Applied: ${file}`);
    }
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
