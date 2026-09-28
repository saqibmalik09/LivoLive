import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  const envPath = join(__dirname, "..", ".env.local");
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const client = new Client({
    connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL,
  });
  await client.connect();
  try {
    const ev = await client.query(
      `\n      SELECT id, title FROM public.party_events\n      WHERE event_kind = 'weekly_star_native' OR screen_template = 'weekly_star'\n      ORDER BY priority DESC, updated_at DESC NULLS LAST\n      LIMIT 1\n    `,
    );
    if (!ev.rows[0]) throw new Error("No Weekly Star event");
    const eventId = ev.rows[0].id;
    console.log("Event:", eventId, ev.rows[0].title);
    const gifts = await client.query(
      `\n      SELECT name, image_url FROM public.shop_items\n      WHERE is_gift = true AND is_active = true\n        AND image_url IS NOT NULL AND image_url <> ''\n      ORDER BY price_coins DESC\n      LIMIT 20\n    `,
    );
    const g = gifts.rows;
    if (g.length === 0) throw new Error("No gift images in shop_items");
    const pick = (i, label) => ({
      label: label,
      image_url: g[i % g.length]?.image_url || "",
    });
    const reward_slots = {
      rank_1: {
        label: "Top 1",
        items: [
          pick(0, "Star Crown x 7d"),
          pick(1, "VIP Frame x 7d"),
          pick(2, "Entry Effect x 7d"),
          pick(3, "Medal TOP1 x 7d"),
          pick(4, "SVIP6 x 7d"),
          pick(5, "Coins 500K"),
          pick(6, "Badge x 7d"),
        ],
      },
      rank_2: {
        label: "Top 2",
        items: [
          pick(1, "VIP Frame x 7d"),
          pick(2, "Medal TOP2 x 7d"),
          pick(3, "SVIP5 x 7d"),
          pick(4, "Coins 250K"),
          pick(5, "Badge x 7d"),
        ],
      },
      rank_3: {
        label: "Top 3",
        items: [
          pick(2, "Medal TOP3 x 7d"),
          pick(3, "SVIP4 x 7d"),
          pick(4, "Coins 150K"),
          pick(5, "Badge x 7d"),
          pick(6, "Frame x 7d"),
        ],
      },
      rank_4_10: {
        label: "Top 4 ~ 10",
        items: [pick(7, "SVIP3 x 7d"), pick(8, "Coins 25K")],
      },
    };
    await client.query(
      `\n      UPDATE public.party_events\n      SET action_config = COALESCE(action_config, '{}'::jsonb)\n        || jsonb_build_object('reward_slots', $2::jsonb),\n          updated_at = now()\n      WHERE id = $1\n    `,
      [eventId, JSON.stringify(reward_slots)],
    );
    console.log("Saved reward_slots:", {
      rank_1: reward_slots.rank_1.items.length,
      rank_2: reward_slots.rank_2.items.length,
      rank_3: reward_slots.rank_3.items.length,
      rank_4_10: reward_slots.rank_4_10.items.length,
    });
    console.log("Done. Open Weekly Star → Reward tab.");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
