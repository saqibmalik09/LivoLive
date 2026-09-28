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
    "20250711120000_rupee_game_system.sql",
  ),
  join(
    adminRoot,
    "..",
    "sk_live",
    "supabase",
    "migrations",
    "20250711130000_bottom_nav_game_tab.sql",
  ),
  join(
    adminRoot,
    "..",
    "sk_live",
    "supabase",
    "migrations",
    "20250711140000_rupee_game_auto_draw_cron.sql",
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
    const campaigns = await client.query(
      "SELECT COUNT(*)::int AS c FROM public.rupee_game_campaigns",
    );
    const help = await client.query(
      "SELECT COUNT(*)::int AS c FROM public.rupee_game_help_sections",
    );
    const gameTab = await client.query(
      "SELECT nav_key FROM public.bottom_nav_items WHERE nav_key = 'game'",
    );
    console.log("rupee_game_campaigns:", campaigns.rows[0].c);
    console.log("rupee_game_help_sections:", help.rows[0].c);
    console.log("bottom_nav game tab:", gameTab.rows[0]?.nav_key ?? "missing");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
