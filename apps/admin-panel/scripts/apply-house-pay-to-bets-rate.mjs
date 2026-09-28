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
  "20260725150000_house_pay_to_bets_rate.sql",
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
  if (!connectionString) throw new Error("DATABASE_URL required");
  if (!existsSync(migrationPath)) throw new Error(`Missing ${migrationPath}`);
  const sql = readFileSync(migrationPath, "utf8");
  const client = new Client({
    connectionString: connectionString,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    await client.query(sql);
    const { rows: rows } = await client.query(
      `\n      SELECT key, value FROM public.system_settings\n      WHERE key IN (\n        'game_control_mode',\n        'game_house_pay_to_bets_rate',\n        'game_house_max_round_rtp',\n        'game_house_soft_edge_rate',\n        'game_house_big_hit_enabled'\n      )\n      ORDER BY key\n    `,
    );
    console.log("Applied. Settings:");
    for (const r of rows) console.log(`  ${r.key}=${r.value}`);
    const fn = await client.query(
      `\n      SELECT pg_get_functiondef('public.resolve_game_winner(uuid)'::regprocedure) AS def\n    `,
    );
    const def = fn.rows[0]?.def || "";
    console.log(
      "resolve_game_winner has pay_to_bets:",
      def.includes("game_house_pay_to_bets_rate"),
    );
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
