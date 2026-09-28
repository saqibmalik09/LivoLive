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
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("Set DATABASE_URL in .env.local");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    const roomRes = await client.query(
      `\n      SELECT r.id, r.title, r.host_id, u.username, u.short_id\n      FROM public.rooms r\n      JOIN public.users u ON u.id = r.host_id\n      WHERE u.short_id = 1010\n         OR r.title ILIKE '%almohsin%'\n         OR u.username ILIKE '%almohsin%'\n      ORDER BY r.is_active DESC NULLS LAST, r.created_at DESC\n      LIMIT 5\n      `,
    );
    if (roomRes.rows.length === 0) {
      throw new Error("No Almohsin Dev room found (short_id 1010 / title match)");
    }
    console.log("Matched rooms:", roomRes.rows);
    const room = roomRes.rows[0];
    const roomId = room.id;
    const hostId = room.host_id;
    const giftRes = await client.query(
      `\n      SELECT id FROM public.shop_items\n      WHERE is_gift = true AND is_active = true\n      ORDER BY price_coins ASC NULLS LAST\n      LIMIT 1\n      `,
    );
    let giftId = giftRes.rows[0]?.id;
    if (!giftId) {
      const g2 = await client.query(`SELECT id FROM public.gifts WHERE is_active = true LIMIT 1`);
      giftId = g2.rows[0]?.id;
    }
    if (!giftId) throw new Error("No gift item found to attach gift_logs");
    const usersRes = await client.query(
      `\n      SELECT id, username\n      FROM public.users\n      WHERE id <> $1::uuid\n        AND coalesce(is_banned, false) = false\n        AND username IS NOT NULL\n      ORDER BY wealth_value DESC NULLS LAST, charm_value DESC NULLS LAST\n      LIMIT 12\n      `,
      [hostId],
    );
    if (usersRes.rows.length === 0) {
      throw new Error("No other users found to seed contributions");
    }
    const scores = [19e5, 126e3, 45200, 18800, 9200, 4100, 2800, 1600, 980, 750, 420, 210];
    const senderIds = usersRes.rows.map((u) => u.id);
    await client.query(
      `\n      DELETE FROM public.gift_logs\n      WHERE room_id = $1::uuid\n        AND sender_id = ANY($2::uuid[])\n        AND created_at >= date_trunc('day', now())\n        AND amount = ANY($3::int[])\n      `,
      [roomId, senderIds, scores],
    );
    for (let i = 0; i < usersRes.rows.length; i++) {
      const sender = usersRes.rows[i];
      const amount = scores[i] ?? 100 * (usersRes.rows.length - i);
      const hoursAgo = i + 1;
      const weeklyAmount = Math.max(100, Math.floor(amount * 0.35));
      await client.query(
        `\n        INSERT INTO public.gift_logs\n          (sender_id, receiver_id, gift_id, room_id, amount, created_at)\n        VALUES\n          ($1::uuid, $2::uuid, $3::uuid, $4::uuid, $5, now() - make_interval(hours => $6)),\n          ($1::uuid, $2::uuid, $3::uuid, $4::uuid, $7, now() - interval '3 days')\n        `,
        [sender.id, hostId, giftId, roomId, amount, hoursAgo, weeklyAmount],
      );
      console.log(`+ ${sender.username}: daily≈${amount}`);
    }
    const check = await client.query(
      `SELECT * FROM public.get_room_contribution_rankings($1::uuid, 'daily') LIMIT 10`,
      [roomId],
    );
    console.log("Daily rankings sample:", check.rows);
    console.log("Done. Open room:", room.title, roomId);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
