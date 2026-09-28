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

async function main() {
  const env = loadEnv();
  const client = new Client({
    connectionString: env.DATABASE_URL,
  });
  await client.connect();
  try {
    let eventRes = await client.query(
      `\n      SELECT id, title, action_config, start_at, end_at\n      FROM public.party_events\n      WHERE event_kind = 'cp_native'\n         OR screen_template IN ('cp_romance', 'cp_event')\n      ORDER BY priority DESC, created_at DESC\n      LIMIT 1\n    `,
    );
    let eventId;
    if (eventRes.rows.length === 0) {
      const ins = await client.query(
        `\n        INSERT INTO public.party_events (\n          title, subtitle, banner_url, event_kind, screen_template,\n          action_type, action_config, start_at, end_at, is_active, priority, updated_at\n        ) VALUES (\n          'Best CP',\n          'Last Week',\n          '',\n          'cp_native',\n          'cp_romance',\n          'none',\n          '{"rules":"Once a CP relationship is successfully formed, rankings are determined based on the total amount of coins both parties receive from CP-exclusive gifts. (1 coin spent on CP gifts = 1 intimacy point).","cta_label":"Open CP Nest","cp_gift_ids":[],"reward_slots":{}}'::jsonb,\n          now() - interval '3 days',\n          now() + interval '4 days',\n          true,\n          100,\n          now()\n        )\n        RETURNING id, title\n      `,
      );
      eventId = ins.rows[0].id;
      console.log("Created CP event:", eventId);
    } else {
      eventId = eventRes.rows[0].id;
      console.log("Using CP event:", eventId, eventRes.rows[0].title);
      await client.query(
        `\n        UPDATE public.party_events\n        SET is_active = true,\n            start_at = COALESCE(start_at, now() - interval '3 days'),\n            end_at = GREATEST(COALESCE(end_at, now()), now() + interval '4 days'),\n            updated_at = now()\n        WHERE id = $1\n      `,
        [eventId],
      );
    }
    const gifts = await client.query(
      `\n      SELECT id, name, price_coins, image_url\n      FROM public.shop_items\n      WHERE is_gift = true AND is_active = true\n      ORDER BY price_coins ASC\n      LIMIT 6\n    `,
    );
    if (gifts.rows.length === 0) {
      throw new Error("No active gift shop_items found. Create gifts in Shop first.");
    }
    const giftIds = gifts.rows.map((g) => g.id);
    console.log("Tagging gifts:", gifts.rows.map((g) => `${g.name} (${g.price_coins})`).join(", "));
    const rewardSlots = {
      rank_1: {
        label: "Top 1 Crown",
        image_url: gifts.rows[gifts.rows.length - 1]?.image_url || "",
      },
      rank_2: {
        label: "Top 2 Frame",
        image_url: gifts.rows[Math.max(0, gifts.rows.length - 2)]?.image_url || "",
      },
      rank_3: {
        label: "Top 3 Badge",
        image_url: gifts.rows[0]?.image_url || "",
      },
      rank_4_10: {
        label: "Rank 4-10",
        items: gifts.rows.slice(0, 3).map((g, i) => ({
          label: `Reward ${i + 1}`,
          image_url: g.image_url || "",
        })),
      },
    };
    await client.query(
      `\n      UPDATE public.party_events\n      SET action_config = COALESCE(action_config, '{}'::jsonb)\n        || jsonb_build_object(\n          'cp_gift_ids', $2::jsonb,\n          'reward_slots', $3::jsonb,\n          'rules', COALESCE(action_config->>'rules',\n            'Once a CP relationship is successfully formed, rankings are determined based on the total amount of coins both parties receive from CP-exclusive gifts. (1 coin spent on CP gifts = 1 intimacy point).')\n        ),\n        updated_at = now()\n      WHERE id = $1\n    `,
      [eventId, JSON.stringify(giftIds), JSON.stringify(rewardSlots)],
    );
    const users = await client.query(
      `\n      SELECT id, username, avatar_url\n      FROM public.users\n      WHERE username IS NOT NULL AND trim(username) <> ''\n      ORDER BY created_at DESC NULLS LAST\n      LIMIT 24\n    `,
    );
    if (users.rows.length < 4) {
      throw new Error(`Need at least 4 users for mock couples, found ${users.rows.length}`);
    }
    const existingCouples = await client.query(
      `\n      SELECT id, user1_id, user2_id FROM public.couples LIMIT 20\n    `,
    );
    console.log("Existing couples:", existingCouples.rowCount);
    const couplePairs = [];
    for (const row of existingCouples.rows) {
      couplePairs.push({
        user1: row.user1_id,
        user2: row.user2_id,
        id: row.id,
      });
    }
    const used = new Set(couplePairs.flatMap((c) => [c.user1, c.user2]));
    const free = users.rows.filter((u) => !used.has(u.id));
    while (couplePairs.length < 8 && free.length >= 2) {
      const u1 = free.shift();
      const u2 = free.shift();
      const ins = await client.query(
        `\n        INSERT INTO public.couples (user1_id, user2_id, cp_exp, cp_level)\n        VALUES ($1, $2, 0, 1)\n        ON CONFLICT DO NOTHING\n        RETURNING id, user1_id, user2_id\n      `,
        [u1.id, u2.id],
      );
      if (ins.rows[0]) {
        couplePairs.push({
          id: ins.rows[0].id,
          user1: ins.rows[0].user1_id,
          user2: ins.rows[0].user2_id,
        });
        console.log("Created couple:", u1.username, "&", u2.username);
      } else {
        break;
      }
    }
    while (couplePairs.length < 8 && free.length >= 2) {
      const u1 = free.shift();
      const u2 = free.shift();
      try {
        const ins = await client.query(
          `\n          INSERT INTO public.couples (user1_id, user2_id, cp_exp, cp_level)\n          VALUES ($1, $2, 0, 1)\n          RETURNING id, user1_id, user2_id\n        `,
          [u1.id, u2.id],
        );
        couplePairs.push({
          id: ins.rows[0].id,
          user1: ins.rows[0].user1_id,
          user2: ins.rows[0].user2_id,
        });
        console.log("Created couple:", u1.username, "&", u2.username);
      } catch (e) {
        console.warn("Skip couple create:", e.message);
        break;
      }
    }
    if (couplePairs.length === 0) {
      throw new Error("No couples available to seed gift logs");
    }
    console.log("Using couples:", couplePairs.length);
    const scoreWeights = [125e4, 53e4, 178e3, 14e4, 98e3, 72e3, 45e3, 28e3];
    let inserted = 0;
    for (let i = 0; i < couplePairs.length; i++) {
      const couple = couplePairs[i];
      const totalTarget = scoreWeights[i] ?? 2e4 - i * 1500;
      const chunks = 4;
      const perChunk = Math.max(1, Math.floor(totalTarget / chunks));
      for (let k = 0; k < chunks; k++) {
        const gift = gifts.rows[k % gifts.rows.length];
        const sender = k % 2 === 0 ? couple.user1 : couple.user2;
        const receiver = k % 2 === 0 ? couple.user2 : couple.user1;
        const amount = perChunk + k * 100;
        await client.query(
          `\n          INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount, created_at)\n          VALUES ($1, $2, $3, NULL, $4, now() - ($5 || ' hours')::interval)\n        `,
          [sender, receiver, gift.id, amount, String(i * 3 + k)],
        );
        inserted++;
      }
      if (i < 3) {
        for (let week = 1; week <= 3; week++) {
          const gift = gifts.rows[week % gifts.rows.length];
          const weekAmount = Math.floor((scoreWeights[i] ?? 5e4) / (week + 1));
          await client.query(
            `\n            INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount, created_at)\n            VALUES (\n              $1, $2, $3, NULL, $4,\n              date_trunc('week', now()) - ($5::int * interval '1 week') + interval '2 days'\n            )\n          `,
            [couple.user1, couple.user2, gift.id, weekAmount, week],
          );
          inserted++;
        }
      }
    }
    console.log("Inserted gift_logs:", inserted);
    await client.query(`SELECT public.refresh_cp_event_rankings($1::uuid)`, [eventId]);
    const ranks = await client.query(
      `\n      SELECT r.rank, r.score, u1.username AS n1, u2.username AS n2\n      FROM public.cp_event_rankings r\n      JOIN public.users u1 ON u1.id = r.user_1_id\n      JOIN public.users u2 ON u2.id = r.user_2_id\n      WHERE r.party_event_id = $1 AND r.period_key = 'current'\n      ORDER BY r.rank ASC\n      LIMIT 12\n    `,
      [eventId],
    );
    console.log("\n=== CP Event Rankings ===");
    for (const row of ranks.rows) {
      console.log(`#${row.rank}  ${row.n1} & ${row.n2}  →  ${row.score}`);
    }
    const giftTop = await client.query(`SELECT * FROM public.get_cp_event_gift_top($1::uuid, 5)`, [
      eventId,
    ]);
    console.log("\n=== Gift Top ===");
    for (const row of giftTop.rows) {
      console.log(
        `${row.gift_name}: ${row.total_amount} (${row.top_sender_name} → ${row.top_receiver_name})`,
      );
    }
    console.log("\nDone. Open the CP event in the app (hot restart) to see mock data.");
    console.log("Event ID:", eventId);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
