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
    const upd = await client.query(
      `\n      UPDATE game_configs\n      SET\n        is_active = true,\n        maintenance_mode = false\n      WHERE config_data->>'provider' = 'tulasi'\n         OR game_url ILIKE '%tulasigame.com%'\n      RETURNING id, slug, name, is_active\n    `,
    );
    console.log("activated_count", upd.rowCount);
    const ids = upd.rows.map((r) => String(r.id));
    if (ids.length > 0) {
      const cleared = await client.query(
        `\n        DELETE FROM room_game_visibility\n        WHERE scope = 'game_config' AND target_id = ANY($1::text[])\n        RETURNING target_id\n        `,
        [ids],
      );
      console.log("cleared_audience_rules", cleared.rowCount);
    }
    const tulasiIds = await client.query(
      `\n      SELECT DISTINCT config_data->>'tulasi_game_id' AS tid\n      FROM game_configs\n      WHERE config_data->>'provider' = 'tulasi'\n        AND config_data->>'tulasi_game_id' IS NOT NULL\n    `,
    );
    const tids = tulasiIds.rows.map((r) => String(r.tid)).filter(Boolean);
    if (tids.length > 0) {
      const cleared2 = await client.query(
        `\n        DELETE FROM room_game_visibility\n        WHERE scope = 'tulasi_game' AND target_id = ANY($1::text[])\n        RETURNING target_id\n        `,
        [tids],
      );
      console.log("cleared_tulasi_audience_rules", cleared2.rowCount);
    }
    const summary = await client.query(
      `\n      SELECT slug, name, is_active, maintenance_mode\n      FROM game_configs\n      WHERE config_data->>'provider' = 'tulasi'\n      ORDER BY sort_order, name\n    `,
    );
    for (const row of summary.rows) {
      console.log(
        `${row.is_active ? "ON" : "OFF"} ${row.slug} — ${row.name}` +
          (row.maintenance_mode ? " [maintenance]" : ""),
      );
    }
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
