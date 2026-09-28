import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

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
    const cats = await client.query(
      `SELECT id, name, is_active, sort_order FROM public.su_game_categories ORDER BY sort_order`,
    );
    console.log("su_game_categories:");
    console.table(cats.rows);
    const items = await client.query(
      `SELECT c.name AS category, i.kind, count(*) AS items,\n              count(*) FILTER (WHERE i.is_active) AS active_items\n         FROM public.su_game_items i\n         LEFT JOIN public.su_game_categories c ON c.id = i.category_id\n        GROUP BY c.name, i.kind\n        ORDER BY c.name, i.kind`,
    );
    console.log("su_game_items by category:");
    console.table(items.rows);
    const orphan = await client.query(
      `SELECT i.game_slug, i.is_active\n         FROM public.su_game_items i\n         LEFT JOIN public.game_configs g ON g.slug = i.game_slug\n        WHERE i.kind = 'h5' AND (g.id IS NULL OR g.is_active = false OR COALESCE(g.game_url,'') = '')\n        ORDER BY i.game_slug`,
    );
    console.log(`hub items that cannot resolve (${orphan.rowCount}):`);
    console.table(orphan.rows.slice(0, 30));
    const missing = await client.query(
      `SELECT g.slug, g.name\n         FROM public.game_configs g\n         LEFT JOIN public.su_game_items i ON i.game_slug = g.slug\n        WHERE g.is_active = true AND i.id IS NULL\n        ORDER BY g.sort_order NULLS LAST, g.name`,
    );
    console.log(`active games missing from hub (${missing.rowCount}):`);
    console.table(missing.rows.slice(0, 60));
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
