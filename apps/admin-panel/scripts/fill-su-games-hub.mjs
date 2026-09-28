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
  if (!connectionString) {
    throw new Error("DATABASE_URL or SUPABASE_DB_URL required in .env.local");
  }
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
    await client.query("BEGIN");
    await client.query(
      `INSERT INTO public.su_game_categories (name, sort_order, is_active)\n       SELECT 'Hot', 0, true\n       WHERE NOT EXISTS (\n         SELECT 1 FROM public.su_game_categories WHERE name = 'Hot'\n       )`,
    );
    await client.query(
      `UPDATE public.su_game_categories\n          SET is_active = true, updated_at = now()\n        WHERE name = 'Hot'`,
    );
    const hot = await client.query(
      `SELECT id FROM public.su_game_categories WHERE name = 'Hot' LIMIT 1`,
    );
    const hotId = hot.rows[0].id;
    const removed = await client.query(
      `DELETE FROM public.su_game_items i\n        WHERE i.kind = 'h5'\n          AND NOT EXISTS (\n            SELECT 1 FROM public.game_configs g WHERE g.slug = i.game_slug\n          )\n        RETURNING i.game_slug`,
    );
    const upserted = await client.query(
      `INSERT INTO public.su_game_items (\n         category_id, kind, game_slug, title, image_url, sort_order, is_active\n       )\n       SELECT $1, 'h5', g.slug, COALESCE(g.name, g.slug),\n              COALESCE(g.icon_url, ''), COALESCE(g.sort_order, 0), true\n         FROM public.game_configs g\n        WHERE g.is_active = true\n          AND COALESCE(g.slug, '') <> ''\n          AND COALESCE(g.game_url, '') <> ''\n       ON CONFLICT (category_id, game_slug) WHERE kind = 'h5' AND game_slug IS NOT NULL\n       DO UPDATE SET\n         title = EXCLUDED.title,\n         image_url = EXCLUDED.image_url,\n         sort_order = EXCLUDED.sort_order,\n         is_active = true,\n         updated_at = now()\n       RETURNING game_slug`,
      [hotId],
    );
    await client.query("COMMIT");
    console.log(`removed stale items: ${removed.rowCount}`);
    console.log(`hot items active:    ${upserted.rowCount}`);
    const cats = await client.query(
      `SELECT c.name, c.is_active,\n              count(i.id) FILTER (WHERE i.is_active) AS active_items\n         FROM public.su_game_categories c\n         LEFT JOIN public.su_game_items i ON i.category_id = c.id\n        GROUP BY c.name, c.is_active, c.sort_order\n        ORDER BY c.sort_order`,
    );
    console.table(cats.rows);
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
