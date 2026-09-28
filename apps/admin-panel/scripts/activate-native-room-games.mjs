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
    await client.query(
      `\n      UPDATE game_configs g\n      SET category_id = c.id\n      FROM room_game_categories c\n      WHERE c.name = 'SK Live Games'\n        AND g.category_id IS NULL\n        AND coalesce(g.config_data->>'provider', '') <> 'tulasi'\n        AND coalesce(g.game_url, '') <> ''\n    `,
    );
    const upd = await client.query(
      `\n      UPDATE game_configs\n      SET is_active = true, maintenance_mode = false\n      WHERE coalesce(game_url, '') <> ''\n        AND coalesce(config_data->>'provider', '') <> 'tulasi'\n      RETURNING slug, name\n    `,
    );
    console.log("native_activated", upd.rowCount);
    const tulasi = await client.query(
      `\n      UPDATE game_configs\n      SET is_active = true, maintenance_mode = false\n      WHERE config_data->>'provider' = 'tulasi'\n         OR game_url ILIKE '%tulasigame.com%'\n      RETURNING slug\n    `,
    );
    console.log("tulasi_ensured_on", tulasi.rowCount);
    const summary = await client.query(
      `\n      SELECT\n        coalesce(c.name, 'Uncategorized') AS category,\n        count(*)::int AS n\n      FROM game_configs g\n      LEFT JOIN room_game_categories c ON c.id = g.category_id\n      WHERE g.is_active\n      GROUP BY 1\n      ORDER BY min(c.sort_order) NULLS LAST, 1\n    `,
    );
    console.log("active_by_category", summary.rows);
    const total = await client.query(`SELECT count(*)::int AS n FROM game_configs WHERE is_active`);
    console.log("active_total", total.rows[0].n);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
