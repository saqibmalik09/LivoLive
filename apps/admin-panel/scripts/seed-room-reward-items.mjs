import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

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
  if (!connectionString) throw new Error("DATABASE_URL required");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    const existing = await client.query(
      `SELECT COUNT(*)::int AS cnt FROM public.room_reward_items`,
    );
    if (existing.rows[0].cnt > 0) {
      console.log(`room_reward_items already has ${existing.rows[0].cnt} rows — skipping seed.`);
      return;
    }
    const shop = await client.query(
      `SELECT id, name, image_url, price_coins\n       FROM public.shop_items\n       WHERE is_active = true\n         AND image_url IS NOT NULL\n         AND btrim(image_url) <> ''\n       ORDER BY price_coins ASC NULLS LAST\n       LIMIT 40`,
    );
    const coinFallback =
      shop.rows.find((r) => /coin/i.test(r.name || ""))?.image_url || shop.rows[0]?.image_url || "";
    if (!coinFallback && shop.rows.length === 0) {
      throw new Error("No shop_items with images to seed from");
    }
    const pick = (i) => shop.rows[i % Math.max(shop.rows.length, 1)];
    const coinAmountsByLevel = {
      1: [200, 300, 500],
      2: [500, 800, 1e3],
      3: [1e3, 1500, 2e3],
      4: [2e3, 3e3, 5e3],
      5: [5e3, 8e3, 1e4],
    };
    const rows = [];
    for (let level = 1; level <= 5; level++) {
      const featured = pick(level * 3);
      rows.push({
        level: level,
        title: featured?.name || `Lv${level} Featured`,
        image_url: featured?.image_url || coinFallback,
        reward_type: featured ? "shop_item" : "coins",
        coin_amount: featured ? 0 : coinAmountsByLevel[level][2],
        shop_item_id: featured?.id || null,
        weight: 5,
        sort_order: 0,
        is_featured: true,
      });
      const coins = coinAmountsByLevel[level];
      coins.forEach((amt, idx) => {
        rows.push({
          level: level,
          title: `${amt} Coins`,
          image_url: coinFallback,
          reward_type: "coins",
          coin_amount: amt,
          shop_item_id: null,
          weight: 20 - idx * 3,
          sort_order: idx + 1,
          is_featured: false,
        });
      });
      for (let j = 0; j < 3; j++) {
        const item = pick(level * 5 + j + 1);
        if (!item) continue;
        rows.push({
          level: level,
          title: item.name || `Reward ${j + 1}`,
          image_url: item.image_url,
          reward_type: "shop_item",
          coin_amount: 0,
          shop_item_id: item.id,
          weight: 8,
          sort_order: 10 + j,
          is_featured: false,
        });
      }
    }
    for (const r of rows) {
      await client.query(
        `INSERT INTO public.room_reward_items\n          (level, title, image_url, reward_type, coin_amount, shop_item_id, weight, sort_order, is_active, is_featured)\n         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,$9)`,
        [
          r.level,
          r.title,
          r.image_url,
          r.reward_type,
          r.coin_amount,
          r.shop_item_id,
          r.weight,
          r.sort_order,
          r.is_featured,
        ],
      );
    }
    const check = await client.query(
      `SELECT level, COUNT(*)::int AS cnt\n       FROM public.room_reward_items\n       GROUP BY level\n       ORDER BY level`,
    );
    console.log("Seeded room_reward_items:", check.rows);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
