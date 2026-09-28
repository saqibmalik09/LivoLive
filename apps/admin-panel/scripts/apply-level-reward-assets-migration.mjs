import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const migrations = [
  join(
    adminRoot,
    "..",
    "sk_live",
    "supabase",
    "migrations",
    "20250703170000_level_reward_assets.sql",
  ),
  join(
    adminRoot,
    "..",
    "sk_live",
    "supabase",
    "migrations",
    "20250703180000_charm_level_assets_nullable_image.sql",
  ),
  join(
    adminRoot,
    "..",
    "sk_live",
    "supabase",
    "migrations",
    "20250703190000_level_reward_entrance.sql",
  ),
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
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("Set DATABASE_URL in .env.local");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    for (const migrationPath of migrations) {
      const sql = readFileSync(migrationPath, "utf8");
      await client.query(sql);
      console.log("Applied:", migrationPath);
    }
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
