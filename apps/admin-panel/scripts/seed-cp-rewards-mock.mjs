import pg from "pg";

import { readFileSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  const env = {};
  for (const line of readFileSync(join(__dirname, "..", ".env.local"), "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const client = new Client({
    connectionString: env.DATABASE_URL,
  });
  await client.connect();
  try {
    const ev = await client.query(
      `\n      SELECT id, action_config FROM party_events\n      WHERE event_kind = 'cp_native' OR screen_template IN ('cp_romance','cp_event')\n      ORDER BY priority DESC LIMIT 1\n    `,
    );
    if (!ev.rows[0]) throw new Error("No CP event");
    const eventId = ev.rows[0].id;
    const gifts = await client.query(
      `\n      SELECT name, image_url FROM shop_items\n      WHERE is_gift = true AND is_active = true AND image_url IS NOT NULL AND image_url <> ''\n      ORDER BY price_coins DESC LIMIT 12\n    `,
    );
    const g = gifts.rows;
    const pick = (i, label) => ({
      label: label,
      image_url: g[i % g.length]?.image_url || "",
    });
    const reward_slots = {
      rank_1: {
        label: "Top 1",
        items: [
          pick(0, "CP Entryeffect TOP1 x 7 days"),
          pick(1, "CP Medal TOP1 x 7 days"),
          pick(2, "CP TOP1 x 7 days"),
          pick(3, "SVIP6 x 7 days"),
        ],
      },
      rank_2: {
        label: "Top 2",
        items: [
          pick(4, "CP Medal TOP2 x 7 days"),
          pick(5, "CP TOP2 x 7 days"),
          pick(6, "SVIP5 x 7 days"),
          pick(7, "250,000"),
        ],
      },
      rank_3: {
        label: "Top 3",
        items: [
          pick(8, "CP Medal TOP3 x 7 days"),
          pick(9, "CP TOP3 x 7 days"),
          pick(10, "SVIP4 x 7 days"),
          pick(11, "150,000"),
        ],
      },
      rank_4_10: {
        label: "Top 4 ~ 10",
        items: [pick(0, "SVIP3 x 7 days"), pick(1, "25,000")],
      },
    };
    await client.query(
      `UPDATE party_events\n       SET action_config = COALESCE(action_config, '{}'::jsonb) || jsonb_build_object('reward_slots', $2::jsonb),\n           updated_at = now()\n       WHERE id = $1`,
      [eventId, JSON.stringify(reward_slots)],
    );
    console.log("Seeded reward_slots on event", eventId);
    console.log(JSON.stringify(reward_slots, null, 2));
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
