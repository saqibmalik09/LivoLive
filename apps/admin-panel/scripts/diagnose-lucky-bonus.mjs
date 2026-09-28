import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

const ROOM_ID = "af18a907-62e6-4d6d-bc70-0d80920d9b27";

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
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!connectionString) throw new Error("Set DATABASE_URL in .env.local");
  const client = new Client({
    connectionString: connectionString,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    console.log("=== configs ===");
    const lucky = await client.query(
      `SELECT gifts_for_bonus_min, gifts_for_bonus_max, bonus_chance_percent,\n              bonus_trigger_mode, is_enabled, bonus_multiplier_min, bonus_multiplier_max\n       FROM lucky_gift_config WHERE id = 1`,
    );
    const pro = await client.query(
      `SELECT gifts_for_bonus_min, gifts_for_bonus_max, bonus_chance_percent,\n              bonus_trigger_mode, is_enabled, bonus_multiplier_min, bonus_multiplier_max\n       FROM lucky_pro_gift_config WHERE id = 1`,
    );
    console.log("lucky", lucky.rows[0]);
    console.log("pro", pro.rows[0]);
    console.log("\n=== shop categories (luck*) ===");
    const cats = await client.query(
      `SELECT id, name FROM shop_categories\n       WHERE lower(name) LIKE '%luck%' OR lower(name) LIKE '%pro%'\n       ORDER BY name`,
    );
    console.log(cats.rows);
    console.log("\n=== recent gift_logs in AlMohsin room (30) ===");
    const logs = await client.query(
      `SELECT gl.created_at, si.name AS gift_name, lower(sc.name) AS category,\n              gl.amount, u.username AS sender, r.username AS receiver,\n              gl.sender_id, gl.receiver_id, gl.gift_id\n       FROM gift_logs gl\n       LEFT JOIN shop_items si ON si.id = gl.gift_id\n       LEFT JOIN shop_categories sc ON sc.id = si.category_id\n       LEFT JOIN users u ON u.id = gl.sender_id\n       LEFT JOIN users r ON r.id = gl.receiver_id\n       WHERE gl.room_id = $1\n       ORDER BY gl.created_at DESC\n       LIMIT 30`,
      [ROOM_ID],
    );
    for (const row of logs.rows) {
      console.log(
        `${row.created_at?.toISOString?.() ?? row.created_at} | ${row.gift_name} [${row.category}] | ${row.amount} | ${row.sender} -> ${row.receiver}`,
      );
    }
    console.log("\n=== category counts in room (last 2h) ===");
    const counts = await client.query(
      `SELECT lower(sc.name) AS category, count(*) AS n\n       FROM gift_logs gl\n       LEFT JOIN shop_items si ON si.id = gl.gift_id\n       LEFT JOIN shop_categories sc ON sc.id = si.category_id\n       WHERE gl.room_id = $1 AND gl.created_at > now() - interval '2 hours'\n       GROUP BY 1\n       ORDER BY n DESC`,
      [ROOM_ID],
    );
    console.log(counts.rows);
    console.log("\n=== counters ===");
    for (const table of [
      "lucky_gift_counters",
      "lucky_gift_sender_counters",
      "lucky_pro_gift_counters",
      "lucky_pro_gift_sender_counters",
    ]) {
      try {
        const r = await client.query(
          `SELECT * FROM ${table} ORDER BY gift_count DESC NULLS LAST LIMIT 15`,
        );
        console.log(table, r.rows);
      } catch (e) {
        console.log(table, "ERR", e.message);
      }
    }
    console.log("\n=== recent bonus logs ===");
    for (const table of ["lucky_gift_bonus_logs", "lucky_pro_gift_bonus_logs"]) {
      try {
        const r = await client.query(
          `SELECT created_at, sender_id, receiver_id, gift_value, bonus_coins\n           FROM ${table} ORDER BY created_at DESC LIMIT 10`,
        );
        console.log(table, r.rows);
      } catch (e) {
        console.log(table, "ERR", e.message);
      }
    }
    console.log("\n=== send_gift category detection snippet ===");
    const fn = await client.query(
      `SELECT pg_get_functiondef(p.oid) AS def\n       FROM pg_proc p\n       JOIN pg_namespace n ON n.oid = p.pronamespace\n       WHERE n.nspname = 'public' AND p.proname = 'send_gift'\n       LIMIT 1`,
    );
    const def = fn.rows[0]?.def ?? "";
    const hits = def
      .split("\n")
      .filter((l) => /lucky|luck|v_is_lucky|v_category|lucky_pro|bonus/i.test(l))
      .slice(0, 80);
    console.log(hits.join("\n"));
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
