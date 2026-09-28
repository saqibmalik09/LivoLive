import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

const FALLBACK_CATEGORY = "More Games";

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
    const roomCats = await client.query(
      `SELECT id, name, sort_order, is_active\n         FROM public.room_game_categories\n        ORDER BY sort_order, name`,
    );
    console.log("room_game_categories:");
    console.table(roomCats.rows);
    await client.query("BEGIN");
    const wantedByName = new Map();
    for (const [i, r] of roomCats.rows.filter((r) => r.is_active).entries()) {
      wantedByName.set(r.name, {
        name: r.name,
        sort: r.sort_order ?? i,
      });
    }
    if (!wantedByName.has(FALLBACK_CATEGORY)) {
      wantedByName.set(FALLBACK_CATEGORY, {
        name: FALLBACK_CATEGORY,
        sort: 900,
      });
    }
    const wanted = [...wantedByName.values()];
    const suIdByName = new Map();
    for (const cat of wanted) {
      const existing = await client.query(
        `SELECT id FROM public.su_game_categories WHERE name = $1 LIMIT 1`,
        [cat.name],
      );
      if (existing.rowCount) {
        await client.query(
          `UPDATE public.su_game_categories\n              SET sort_order = $2, is_active = true, updated_at = now()\n            WHERE id = $1`,
          [existing.rows[0].id, cat.sort],
        );
        suIdByName.set(cat.name, existing.rows[0].id);
      } else {
        const ins = await client.query(
          `INSERT INTO public.su_game_categories (name, sort_order, is_active)\n           VALUES ($1, $2, true) RETURNING id`,
          [cat.name, cat.sort],
        );
        suIdByName.set(cat.name, ins.rows[0].id);
      }
    }
    const keepNames = [...suIdByName.keys()];
    await client.query(
      `UPDATE public.su_game_categories\n          SET is_active = false, updated_at = now()\n        WHERE name <> ALL($1::text[])`,
      [keepNames],
    );
    await client.query(`DELETE FROM public.su_game_items WHERE kind = 'h5'`);
    const games = await client.query(
      `SELECT g.slug, g.name, g.icon_url, g.sort_order, c.name AS category_name\n         FROM public.game_configs g\n         LEFT JOIN public.room_game_categories c\n                ON c.id = g.category_id AND c.is_active = true\n        WHERE g.is_active = true\n          AND COALESCE(g.slug, '') <> ''\n          AND COALESCE(g.game_url, '') <> ''\n        ORDER BY g.sort_order DESC NULLS LAST, g.name`,
    );
    let placed = 0;
    for (const g of games.rows) {
      const catName = g.category_name || FALLBACK_CATEGORY;
      const catId = suIdByName.get(catName) ?? suIdByName.get(FALLBACK_CATEGORY);
      await client.query(
        `INSERT INTO public.su_game_items (\n           category_id, kind, game_slug, title, image_url, sort_order, is_active\n         ) VALUES ($1, 'h5', $2, $3, $4, $5, true)\n         ON CONFLICT (category_id, game_slug) WHERE kind = 'h5' AND game_slug IS NOT NULL\n         DO UPDATE SET title = EXCLUDED.title,\n                       image_url = EXCLUDED.image_url,\n                       sort_order = EXCLUDED.sort_order,\n                       is_active = true,\n                       updated_at = now()`,
        [catId, g.slug, g.name ?? g.slug, g.icon_url ?? "", g.sort_order ?? 0],
      );
      placed++;
    }
    await client.query(
      `UPDATE public.su_game_categories c\n          SET is_active = false, updated_at = now()\n        WHERE NOT EXISTS (\n          SELECT 1 FROM public.su_game_items i\n           WHERE i.category_id = c.id AND i.is_active\n        )`,
    );
    await client.query("COMMIT");
    console.log(`games placed: ${placed}`);
    const summary = await client.query(
      `SELECT c.name, c.sort_order, c.is_active,\n              count(i.id) FILTER (WHERE i.is_active) AS games\n         FROM public.su_game_categories c\n         LEFT JOIN public.su_game_items i ON i.category_id = c.id\n        GROUP BY c.name, c.sort_order, c.is_active\n        ORDER BY c.sort_order, c.name`,
    );
    console.table(summary.rows);
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
