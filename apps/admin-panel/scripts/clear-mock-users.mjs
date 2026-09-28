import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const USER_PREFIXES = ["de000000", "b1000001"];

const AGENCY_PREFIXES = ["de010000", "b2000001"];

const ROOM_PREFIXES = ["de020000", "b3000001"];

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

function likeAny(col, prefixes) {
  return prefixes.map((p) => `${col}::text LIKE '${p}-%'`).join(" OR ");
}

function log(msg) {
  console.log(`[${new Date().toISOString().slice(11, 19)}] ${msg}`);
}

async function safeDelete(client, label, sql) {
  try {
    const res = await client.query(sql);
    const n = res.rowCount ?? 0;
    if (n > 0) log(`deleted ${n} from ${label}`);
    return n;
  } catch (err) {
    if (err?.code === "42P01" || err?.code === "42703") {
      log(`skip ${label} (${err.code})`);
      return 0;
    }
    throw err;
  }
}

async function countMock(client) {
  const userPred = `(${likeAny("id", USER_PREFIXES)}) OR username ILIKE 'DemoUser_%'`;
  const authPred = `(${likeAny("id", USER_PREFIXES)}) OR email ILIKE '%@sklive.test'`;
  const res = await client.query(
    `\n    SELECT\n      (SELECT COUNT(*)::int FROM public.users WHERE ${userPred}) AS public_users,\n      (SELECT COUNT(*)::int FROM auth.users WHERE ${authPred}) AS auth_users,\n      (SELECT COUNT(*)::int FROM public.rooms WHERE ${likeAny("id", ROOM_PREFIXES)}) AS rooms,\n      (SELECT COUNT(*)::int FROM public.agencies WHERE ${likeAny("id", AGENCY_PREFIXES)}) AS agencies\n  `,
  );
  return res.rows[0];
}

async function clearMock(client) {
  const userPred = `(${likeAny("id", USER_PREFIXES)}) OR username ILIKE 'DemoUser_%'`;
  const authPred = `(${likeAny("id", USER_PREFIXES)}) OR email ILIKE '%@sklive.test'`;
  const roomPred = likeAny("id", ROOM_PREFIXES);
  const agencyPred = likeAny("id", AGENCY_PREFIXES);
  await client.query(`DROP TABLE IF EXISTS _mock_user_ids`);
  await client.query(
    `\n    CREATE TEMP TABLE _mock_user_ids AS\n    SELECT id FROM public.users WHERE ${userPred}\n    UNION\n    SELECT id FROM auth.users WHERE ${authPred}\n  `,
  );
  await client.query(`CREATE INDEX ON _mock_user_ids (id)`);
  const uidCount = (await client.query(`SELECT COUNT(*)::int AS n FROM _mock_user_ids`)).rows[0].n;
  log(`mock user ids resolved: ${uidCount}`);
  await client.query(`DROP TABLE IF EXISTS _mock_room_ids`);
  await client.query(
    `\n    CREATE TEMP TABLE _mock_room_ids AS\n    SELECT id FROM public.rooms\n    WHERE ${roomPred}\n       OR host_id IN (SELECT id FROM _mock_user_ids)\n  `,
  );
  await client.query(`DROP TABLE IF EXISTS _mock_agency_ids`);
  await client.query(
    `\n    CREATE TEMP TABLE _mock_agency_ids AS\n    SELECT id FROM public.agencies\n    WHERE ${agencyPred}\n       OR owner_id IN (SELECT id FROM _mock_user_ids)\n  `,
  );
  await safeDelete(
    client,
    "gift_logs (rooms)",
    `DELETE FROM public.gift_logs WHERE room_id IN (SELECT id FROM _mock_room_ids)`,
  );
  await safeDelete(
    client,
    "gift_logs (users)",
    `DELETE FROM public.gift_logs\n     WHERE sender_id IN (SELECT id FROM _mock_user_ids)\n        OR receiver_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "room_rankings",
    `DELETE FROM public.room_rankings WHERE room_id IN (SELECT id FROM _mock_room_ids)`,
  );
  await safeDelete(
    client,
    "room_stats",
    `DELETE FROM public.room_stats WHERE room_id IN (SELECT id FROM _mock_room_ids)`,
  );
  await safeDelete(
    client,
    "room_seats",
    `DELETE FROM public.room_seats WHERE room_id IN (SELECT id FROM _mock_room_ids)\n       OR user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "room_members",
    `DELETE FROM public.room_members WHERE room_id IN (SELECT id FROM _mock_room_ids)\n       OR user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "room_messages",
    `DELETE FROM public.room_messages WHERE room_id IN (SELECT id FROM _mock_room_ids)\n       OR user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "earning_logs",
    `DELETE FROM public.earning_logs\n     WHERE user_id IN (SELECT id FROM _mock_user_ids)\n        OR room_id IN (SELECT id FROM _mock_room_ids)`,
  );
  await safeDelete(
    client,
    "transactions",
    `DELETE FROM public.transactions\n     WHERE user_id IN (SELECT id FROM _mock_user_ids)\n        OR related_user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "rooms",
    `DELETE FROM public.rooms WHERE id IN (SELECT id FROM _mock_room_ids)`,
  );
  await safeDelete(
    client,
    "agency_rankings",
    `DELETE FROM public.agency_rankings WHERE agency_id IN (SELECT id FROM _mock_agency_ids)`,
  );
  await safeDelete(
    client,
    "agency_members",
    `DELETE FROM public.agency_members\n     WHERE agency_id IN (SELECT id FROM _mock_agency_ids)\n        OR user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "agencies",
    `DELETE FROM public.agencies WHERE id IN (SELECT id FROM _mock_agency_ids)`,
  );
  await safeDelete(
    client,
    "gift_rankings",
    `DELETE FROM public.gift_rankings WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "charm_rankings",
    `DELETE FROM public.charm_rankings WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "wealth_rankings",
    `DELETE FROM public.wealth_rankings WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "user_inventory",
    `DELETE FROM public.user_inventory WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "user_cosmetics",
    `DELETE FROM public.user_cosmetics WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "user_badges",
    `DELETE FROM public.user_badges WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "user_follows",
    `DELETE FROM public.user_follows\n     WHERE follower_id IN (SELECT id FROM _mock_user_ids)\n        OR following_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "friendships",
    `DELETE FROM public.friendships\n     WHERE user_id IN (SELECT id FROM _mock_user_ids)\n        OR friend_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "notifications",
    `DELETE FROM public.notifications WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "wallet_transactions",
    `DELETE FROM public.wallet_transactions WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "cp_event_scores",
    `DELETE FROM public.cp_event_scores\n     WHERE user_id IN (SELECT id FROM _mock_user_ids)\n        OR couple_id IN (\n          SELECT id FROM public.couples\n          WHERE user1_id IN (SELECT id FROM _mock_user_ids)\n             OR user2_id IN (SELECT id FROM _mock_user_ids)\n        )`,
  );
  await safeDelete(
    client,
    "couples",
    `DELETE FROM public.couples\n     WHERE user1_id IN (SELECT id FROM _mock_user_ids)\n        OR user2_id IN (SELECT id FROM _mock_user_ids)`,
  );
  const extra = await client.query(
    `\n    SELECT c.table_name, c.column_name\n    FROM information_schema.columns c\n    JOIN information_schema.tables t\n      ON t.table_schema = c.table_schema AND t.table_name = c.table_name\n    WHERE c.table_schema = 'public'\n      AND t.table_type = 'BASE TABLE'\n      AND c.udt_name = 'uuid'\n      AND c.column_name IN (\n        'user_id', 'sender_id', 'receiver_id', 'host_id', 'owner_id',\n        'from_user_id', 'to_user_id', 'buyer_id', 'seller_id',\n        'creator_id', 'admin_id', 'target_user_id', 'related_user_id'\n      )\n      AND c.table_name NOT IN (\n        'users', 'rooms', 'agencies'\n      )\n    ORDER BY c.table_name, c.column_name\n  `,
  );
  const seen = new Set();
  for (const row of extra.rows) {
    const key = `${row.table_name}.${row.column_name}`;
    if (seen.has(key)) continue;
    seen.add(key);
    await safeDelete(
      client,
      key,
      `DELETE FROM public.${row.table_name}\n       WHERE ${row.column_name} IN (SELECT id FROM _mock_user_ids)`,
    );
  }
  await safeDelete(
    client,
    "public.users",
    `DELETE FROM public.users WHERE id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "auth.identities",
    `DELETE FROM auth.identities WHERE user_id IN (SELECT id FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "auth.sessions",
    `DELETE FROM auth.sessions WHERE user_id::text IN (SELECT id::text FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "auth.refresh_tokens",
    `DELETE FROM auth.refresh_tokens WHERE user_id::text IN (SELECT id::text FROM _mock_user_ids)`,
  );
  await safeDelete(
    client,
    "auth.users",
    `DELETE FROM auth.users WHERE id IN (SELECT id FROM _mock_user_ids)`,
  );
}

async function main() {
  const env = loadEnv();
  const databaseUrl = env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL not set in .env.local");
  const dryRun = process.argv.includes("--dry-run");
  const client = new Client({
    connectionString: databaseUrl,
    ssl: false,
  });
  await client.connect();
  const started = Date.now();
  try {
    await client.query("SET statement_timeout = 0");
    const before = await countMock(client);
    console.log("\nMock data before:");
    console.log(`  public.users : ${before.public_users}`);
    console.log(`  auth.users   : ${before.auth_users}`);
    console.log(`  rooms        : ${before.rooms}`);
    console.log(`  agencies     : ${before.agencies}`);
    if (dryRun) {
      console.log("\nDry run only — nothing deleted.");
      return;
    }
    if (before.public_users === 0 && before.auth_users === 0) {
      console.log("\nNothing to delete.");
      return;
    }
    log("Starting clear (FK checks bypassed)…");
    await client.query("SET session_replication_role = replica");
    await clearMock(client);
    await client.query("SET session_replication_role = DEFAULT");
    const after = await countMock(client);
    const secs = ((Date.now() - started) / 1e3).toFixed(1);
    console.log("\nMock data after:");
    console.log(`  public.users : ${after.public_users}`);
    console.log(`  auth.users   : ${after.auth_users}`);
    console.log(`  rooms        : ${after.rooms}`);
    console.log(`  agencies     : ${after.agencies}`);
    console.log(`\nDone in ${secs}s`);
  } finally {
    await client.query("SET session_replication_role = DEFAULT").catch(() => {});
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
