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
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

const DEFAULT_RULES = [
  "1. Only the specified gifts received will be counted for points. All other gifts are invalid.",
  "2. Receiving a specified gift awards the points shown under that gift.",
  "3. The points are updated in real time. The final ranking is based on the list at the end of the event.",
  "4. After the event ends, the system will automatically send the rewards.",
].join("\n");

const POINT_PRESETS = [500, 5e3, 1e5, 1e6];

async function main() {
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("Set DATABASE_URL in .env.local");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    let eventRes = await client.query(
      `\n      SELECT id, title, action_config\n      FROM public.party_events\n      WHERE event_kind = 'weekly_star_native'\n         OR screen_template = 'weekly_star'\n      ORDER BY priority DESC, updated_at DESC NULLS LAST\n      LIMIT 1\n    `,
    );
    let eventId;
    if (eventRes.rows.length === 0) {
      const ins = await client.query(
        `\n        INSERT INTO public.party_events (\n          title, subtitle, banner_url, event_kind, screen_template,\n          action_type, action_config, start_at, end_at, is_active, priority, updated_at\n        ) VALUES (\n          'Weekly Star',\n          'Shining Star',\n          '',\n          'weekly_star_native',\n          'weekly_star',\n          'none',\n          $1::jsonb,\n          now() - interval '10 days',\n          now() + interval '20 days',\n          true,\n          20,\n          now()\n        )\n        RETURNING id, title\n      `,
        [
          JSON.stringify({
            rules: DEFAULT_RULES,
            weekly_star_gifts: [],
            weekly_star_gift_ids: [],
            reward_slots: {},
          }),
        ],
      );
      eventId = ins.rows[0].id;
      console.log("Created Weekly Star event:", eventId);
    } else {
      eventId = eventRes.rows[0].id;
      console.log("Using Weekly Star event:", eventId, eventRes.rows[0].title);
      await client.query(
        `\n        UPDATE public.party_events\n        SET is_active = true,\n            start_at = LEAST(COALESCE(start_at, now()), now() - interval '10 days'),\n            end_at = GREATEST(COALESCE(end_at, now()), now() + interval '20 days'),\n            updated_at = now()\n        WHERE id = $1\n      `,
        [eventId],
      );
    }
    const gifts = await client.query(
      `\n      SELECT id, name, image_url, price_coins\n      FROM public.shop_items\n      WHERE is_gift = true AND is_active = true\n      ORDER BY price_coins ASC\n      LIMIT 4\n    `,
    );
    if (gifts.rows.length === 0) {
      throw new Error("No active gift shop_items found");
    }
    const weeklyGifts = gifts.rows.map((g, i) => ({
      gift_id: g.id,
      points: POINT_PRESETS[i] ?? Math.max(Number(g.price_coins) || 100, 100),
    }));
    console.log(
      "Gifts:",
      weeklyGifts.map((g, i) => ({
        name: gifts.rows[i].name,
        points: g.points,
      })),
    );
    await client.query(
      `\n      UPDATE public.party_events\n      SET action_config = COALESCE(action_config, '{}'::jsonb)\n        || jsonb_build_object(\n          'rules', COALESCE(NULLIF(action_config->>'rules', ''), $2),\n          'weekly_star_gifts', $3::jsonb,\n          'weekly_star_gift_ids', $4::jsonb\n        ),\n        updated_at = now()\n      WHERE id = $1\n    `,
      [
        eventId,
        DEFAULT_RULES,
        JSON.stringify(weeklyGifts),
        JSON.stringify(weeklyGifts.map((g) => g.gift_id)),
      ],
    );
    const users = await client.query(
      `\n      SELECT id, username, short_id, avatar_url\n      FROM public.users\n      WHERE username IS NOT NULL\n      ORDER BY created_at DESC NULLS LAST\n      LIMIT 25\n    `,
    );
    if (users.rows.length < 3) {
      throw new Error("Need at least 3 users in public.users");
    }
    console.log("Users for mock:", users.rows.length);
    const senderId = users.rows[0].id;
    const receivers = users.rows;
    const giftIds = weeklyGifts.map((g) => g.gift_id);
    const thisWeekStart = await client.query(`SELECT date_trunc('week', now()) AS s`);
    const weekStart = thisWeekStart.rows[0].s;
    const lastWeekStartRes = await client.query(
      `SELECT date_trunc('week', now()) - interval '1 week' AS s`,
    );
    const lastWeekStart = lastWeekStartRes.rows[0].s;
    await client.query(
      `\n      DELETE FROM public.gift_logs\n      WHERE gift_id = ANY($1::uuid[])\n        AND created_at >= $2::timestamptz\n        AND receiver_id = ANY($3::uuid[])\n        AND sender_id = $4\n    `,
      [giftIds, lastWeekStart, receivers.map((u) => u.id), senderId],
    );
    async function seedReceives(userId, giftIndex, count, at) {
      const gift = weeklyGifts[giftIndex % weeklyGifts.length];
      const shop = gifts.rows[giftIndex % gifts.rows.length];
      const amount = Number(shop.price_coins) || gift.points;
      for (let i = 0; i < count; i++) {
        await client.query(
          `\n          INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, amount, created_at)\n          VALUES ($1, $2, $3, $4, $5::timestamptz + ($6 || ' seconds')::interval)\n        `,
          [senderId, userId, gift.gift_id, amount, at, i],
        );
      }
    }
    const thisWeekPattern = [
      [1, [2, 1, 1, 0]],
      [2, [1, 2, 0, 0]],
      [3, [3, 0, 0, 0]],
      [4, [0, 1, 0, 0]],
      [5, [5, 0, 0, 0]],
      [6, [2, 0, 0, 0]],
      [7, [1, 0, 0, 0]],
      [8, [0, 0, 1, 0]],
      [9, [4, 0, 0, 0]],
      [10, [1, 1, 0, 0]],
      [11, [2, 0, 0, 0]],
      [12, [1, 0, 0, 0]],
      [13, [3, 0, 0, 0]],
      [14, [1, 0, 0, 0]],
      [15, [2, 1, 0, 0]],
      [16, [1, 0, 0, 0]],
      [17, [0, 1, 0, 0]],
      [18, [2, 0, 0, 0]],
      [19, [1, 0, 0, 0]],
      [20, [1, 0, 0, 0]],
    ];
    const nowIso = new Date().toISOString();
    for (const [ui, counts] of thisWeekPattern) {
      if (ui >= receivers.length) continue;
      const uid = receivers[ui].id;
      if (uid === senderId) continue;
      for (let gi = 0; gi < counts.length; gi++) {
        if (counts[gi] > 0) {
          await seedReceives(uid, gi, counts[gi], nowIso);
        }
      }
    }
    const lastWeekAt = new Date(
      new Date(lastWeekStart).getTime() + 2 * 24 * 3600 * 1e3,
    ).toISOString();
    const lastWeekPattern = [
      [2, [1, 1, 1, 0]],
      [3, [2, 1, 0, 0]],
      [4, [0, 0, 1, 0]],
      [5, [3, 0, 0, 0]],
      [6, [1, 0, 0, 0]],
      [7, [0, 2, 0, 0]],
      [8, [1, 0, 0, 0]],
    ];
    for (const [ui, counts] of lastWeekPattern) {
      if (ui >= receivers.length) continue;
      const uid = receivers[ui].id;
      if (uid === senderId) continue;
      for (let gi = 0; gi < counts.length; gi++) {
        if (counts[gi] > 0) {
          await seedReceives(uid, gi, counts[gi], lastWeekAt);
        }
      }
    }
    await client.query(`SELECT public.refresh_weekly_star_rankings($1)`, [eventId]);
    const current = await client.query(
      `\n      SELECT rank, score, u.username\n      FROM public.weekly_star_rankings r\n      JOIN public.users u ON u.id = r.user_id\n      WHERE r.party_event_id = $1 AND r.period_key = 'current'\n      ORDER BY r.rank\n      LIMIT 10\n    `,
      [eventId],
    );
    const last = await client.query(
      `\n      SELECT rank, score, u.username\n      FROM public.weekly_star_rankings r\n      JOIN public.users u ON u.id = r.user_id\n      WHERE r.party_event_id = $1 AND r.period_key = 'last'\n      ORDER BY r.rank\n      LIMIT 5\n    `,
      [eventId],
    );
    console.log("This week top:", current.rows);
    console.log("Last week top:", last.rows);
    console.log("Done. Open Weekly Star in the app.");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
