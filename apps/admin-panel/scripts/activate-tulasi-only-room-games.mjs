import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

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

function isTulasiSql() {
  return `(\n    config_data->>'provider' = 'tulasi'\n    OR game_url ILIKE '%tulasigame.com%'\n  )`;
}

async function main() {
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("DATABASE_URL required");
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
    const off = await client.query(
      `\n      UPDATE game_configs\n      SET is_active = false\n      WHERE NOT ${isTulasiSql()}\n      RETURNING slug\n    `,
    );
    console.log("native_off", off.rowCount);
    const on = await client.query(
      `\n      UPDATE game_configs\n      SET is_active = true, maintenance_mode = false\n      WHERE ${isTulasiSql()}\n      RETURNING slug, name\n    `,
    );
    console.log("tulasi_on", on.rowCount);
    for (const row of on.rows) {
      console.log(`ON ${row.slug} — ${row.name}`);
    }
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
