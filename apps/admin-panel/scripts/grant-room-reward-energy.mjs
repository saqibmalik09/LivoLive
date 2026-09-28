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
  const cs = env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!cs) throw new Error("DATABASE_URL required");
  const client = new Client({
    connectionString: cs,
  });
  await client.connect();
  try {
    const userRes = await client.query(
      `SELECT id, username FROM public.users\n       WHERE username ILIKE '%AlMohsin Dev%' OR username ILIKE 'almohsin%'\n       ORDER BY CASE WHEN username ILIKE '%AlMohsin Dev%' THEN 0 ELSE 1 END\n       LIMIT 5`,
    );
    const user = userRes.rows[0];
    if (!user) throw new Error("User AlMohsin Dev not found");
    console.log("user:", user);
    const roomCols = await client.query(
      `SELECT column_name FROM information_schema.columns\n       WHERE table_schema='public' AND table_name='rooms'`,
    );
    const colSet = new Set(roomCols.rows.map((r) => r.column_name));
    const ownerCol = ["host_id", "owner_id", "creator_id", "user_id", "created_by"].find((c) =>
      colSet.has(c),
    );
    const rooms = await client.query(
      `SELECT id, title${ownerCol ? `, ${ownerCol}` : ""}\n       FROM public.rooms\n       WHERE title ILIKE '%almohsin%' OR title ILIKE '%mohsin%'\n          OR (${ownerCol ? `${ownerCol} = $1` : "false"})\n       ORDER BY\n         CASE WHEN title ILIKE '%AlMohsin%' THEN 0\n              WHEN title ILIKE '%mohsin%' THEN 1\n              ELSE 2 END\n       LIMIT 10`,
      ownerCol ? [user.id] : [],
    );
    console.log("rooms:", rooms.rows);
    const room =
      rooms.rows.find((r) => /almohsin/i.test(r.title || "")) ||
      rooms.rows.find((r) => ownerCol && r[ownerCol] === user.id) ||
      rooms.rows[0];
    if (!room) throw new Error("Room not found for AlMohsin");
    const targetLevel = Math.max(1, Number(process.argv[2] || 1) || 1);
    const lvl = await client.query(
      `SELECT required_points FROM public.room_reward_levels WHERE level = $1`,
      [targetLevel],
    );
    if (!lvl.rows[0]) throw new Error(`Level ${targetLevel} not found`);
    const required = Number(lvl.rows[0].required_points);
    const energyRes = await client.query(
      `SELECT COALESCE(SUM(amount),0)::bigint AS energy\n       FROM public.gift_logs WHERE room_id = $1 AND sender_id = $2`,
      [room.id, user.id],
    );
    const current = Number(energyRes.rows[0].energy);
    const need = Math.max(0, required - current + 1);
    console.log({
      room: room.title,
      roomId: room.id,
      targetLevel: targetLevel,
      required: required,
      current: current,
      need: need,
    });
    await client.query(
      `DELETE FROM public.room_reward_claims\n       WHERE user_id = $1 AND room_id = $2 AND level = $3`,
      [user.id, room.id, targetLevel],
    );
    if (need > 0) {
      const gift = await client.query(
        `SELECT id FROM public.shop_items\n         WHERE is_gift = true AND is_active = true LIMIT 1`,
      );
      const giftId = gift.rows[0]?.id;
      if (!giftId) throw new Error("No gift item");
      const receiverId =
        (ownerCol && room[ownerCol]) ||
        (await client.query(`SELECT id FROM public.users WHERE id <> $1 LIMIT 1`, [user.id]))
          .rows[0]?.id ||
        user.id;
      await client.query(
        `INSERT INTO public.gift_logs\n           (sender_id, receiver_id, gift_id, room_id, amount)\n         VALUES ($1,$2,$3,$4,$5)`,
        [user.id, receiverId, giftId, room.id, need],
      );
    }
    const after = await client.query(
      `SELECT COALESCE(SUM(amount),0)::bigint AS energy\n       FROM public.gift_logs WHERE room_id = $1 AND sender_id = $2`,
      [room.id, user.id],
    );
    const claim = await client.query(
      `SELECT level FROM public.room_reward_claims\n       WHERE user_id = $1 AND room_id = $2`,
      [user.id, room.id],
    );
    console.log("DONE energy=", after.rows[0].energy, "claims=", claim.rows);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
