import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

const OLD_MERCHANT = "1000002";

const NEW_MERCHANT = "1503241";

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("DATABASE_URL required in .env.local");
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
    const urls = await client.query(
      `UPDATE game_configs\n          SET game_url = replace(game_url, $1, $2)\n        WHERE game_url LIKE '%merchant=' || $1 || '%'\n        RETURNING slug, game_url`,
      [OLD_MERCHANT, NEW_MERCHANT],
    );
    console.log("game_url updated:", urls.rowCount);
    for (const row of urls.rows) console.log(" ", row.slug, row.game_url);
    const cfg = await client.query(
      `UPDATE game_configs\n          SET config_data = jsonb_set(\n                config_data, '{tulasi_merchant_id}', to_jsonb($1::text), true\n              )\n        WHERE config_data->>'provider' = 'tulasi'\n          AND coalesce(config_data->>'tulasi_merchant_id', '') <> $1\n        RETURNING slug`,
      [NEW_MERCHANT],
    );
    console.log("config_data.tulasi_merchant_id updated:", cfg.rowCount);
    const left = await client.query(
      `SELECT count(*)::int AS n FROM game_configs\n        WHERE game_url LIKE '%merchant=' || $1 || '%'`,
      [OLD_MERCHANT],
    );
    console.log("rows still on old merchant:", left.rows[0].n);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
