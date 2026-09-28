import fs from "fs";

import path from "path";

import { fileURLToPath } from "url";

import pg from "pg";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadEnvLocal() {
  const envPath = path.join(__dirname, "..", ".env.local");
  const env = {};
  if (!fs.existsSync(envPath)) return env;
  for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (!m) continue;
    env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

async function main() {
  const env = loadEnvLocal();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("DATABASE_URL required");
  const sqlPath = path.join(
    __dirname,
    "..",
    "..",
    "sklive-mobile",
    "supabase",
    "migrations",
    "20260801250000_game_webview_height_percent.sql",
  );
  const sql = fs.readFileSync(sqlPath, "utf8");
  const client = new pg.Client({
    connectionString: connectionString,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    await client.query(sql);
    console.log("Applied 20260801250000_game_webview_height_percent.sql");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
