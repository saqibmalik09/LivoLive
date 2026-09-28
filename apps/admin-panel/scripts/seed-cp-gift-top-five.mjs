import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

function loadEnv() {
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
    const ev = await client.query(
      `\n      SELECT id, action_config FROM party_events\n      WHERE event_kind = 'cp_native' OR screen_template IN ('cp_romance','cp_event')\n      ORDER BY priority DESC LIMIT 1\n    `,
    );
    if (!ev.rows[0]) throw new Error("No CP event");
    const eventId = ev.rows[0].id;
    let giftIds = ev.rows[0].action_config?.cp_gift_ids ?? [];
    if (!Array.isArray(giftIds) || giftIds.length < 5) {
      const gifts = await client.query(
        `\n        SELECT id FROM shop_items WHERE is_gift=true AND is_active=true\n        ORDER BY price_coins ASC LIMIT 6\n      `,
      );
      giftIds = gifts.rows.map((r) => r.id);
      await client.query(
        `UPDATE party_events SET action_config = action_config || jsonb_build_object('cp_gift_ids', $2::jsonb), updated_at=now() WHERE id=$1`,
        [eventId, JSON.stringify(giftIds)],
      );
    }
    const couples = await client.query(`SELECT user1_id, user2_id FROM couples LIMIT 5`);
    if (couples.rowCount === 0) throw new Error("No couples");
    const amounts = [9e4, 75e3, 6e4, 45e3, 3e4];
    for (let i = 0; i < 5; i++) {
      const giftId = giftIds[i];
      const c = couples.rows[i % couples.rowCount];
      await client.query(
        `INSERT INTO gift_logs (sender_id, receiver_id, gift_id, room_id, amount, created_at)\n         VALUES ($1,$2,$3,NULL,$4, now() - interval '1 hour')`,
        [c.user1_id, c.user2_id, giftId, amounts[i]],
      );
    }
    await client.query(`SELECT refresh_cp_event_rankings($1::uuid)`, [eventId]);
    const top = await client.query(
      `SELECT gift_name, total_amount FROM get_cp_event_gift_top($1::uuid, 5)`,
      [eventId],
    );
    console.log("Gift Top (5):");
    for (const r of top.rows) console.log(` - ${r.gift_name}: ${r.total_amount}`);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
