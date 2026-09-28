import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const USER_PREFIX = "de000000";

const AGENCY_PREFIX = "de010000";

const ROOM_PREFIX = "de020000";

const CONTRIBUTORS_PER_ROOM = 8;

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

function demoUuid(prefix, n) {
  return `${prefix}-0000-4000-8000-${n.toString(16).padStart(12, "0")}`;
}

function log(step, detail = "") {
  const ts = new Date().toISOString().slice(11, 19);
  console.log(`[${ts}] ${step}${detail ? ` — ${detail}` : ""}`);
}

async function cleanBulkDemo(client) {
  log("Cleaning previous bulk demo data…");
  await client.query(
    `\n    DELETE FROM public.gift_logs WHERE room_id::text LIKE '${ROOM_PREFIX}-%';\n    DELETE FROM public.room_rankings WHERE room_id::text LIKE '${ROOM_PREFIX}-%';\n    DELETE FROM public.room_stats WHERE room_id::text LIKE '${ROOM_PREFIX}-%';\n    DELETE FROM public.rooms WHERE id::text LIKE '${ROOM_PREFIX}-%';\n    DELETE FROM public.agency_rankings WHERE agency_id::text LIKE '${AGENCY_PREFIX}-%';\n    DELETE FROM public.agency_members WHERE agency_id::text LIKE '${AGENCY_PREFIX}-%';\n    DELETE FROM public.agencies WHERE id::text LIKE '${AGENCY_PREFIX}-%';\n    DELETE FROM public.gift_rankings WHERE user_id::text LIKE '${USER_PREFIX}-%';\n    DELETE FROM public.charm_rankings WHERE user_id::text LIKE '${USER_PREFIX}-%';\n    DELETE FROM public.users WHERE id::text LIKE '${USER_PREFIX}-%';\n    DELETE FROM auth.identities WHERE user_id::text LIKE '${USER_PREFIX}-%';\n    DELETE FROM auth.users WHERE id::text LIKE '${USER_PREFIX}-%';\n  `,
  );
}

async function seedBulk(client, totalUsers, agencyCount, pwdHash, giftId) {
  log("auth.users", `1..${totalUsers}`);
  await client.query(
    `\n    INSERT INTO auth.users (\n      id, instance_id, aud, role, email, encrypted_password,\n      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at\n    )\n    SELECT\n      ('${USER_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      '00000000-0000-0000-0000-000000000000'::uuid,\n      'authenticated',\n      'authenticated',\n      'demo-bulk-' || n || '@sklive.test',\n      $1::text,\n      now(),\n      '{"provider":"email","providers":["email"]}'::jsonb,\n      jsonb_build_object('username', 'DemoUser_' || n),\n      now(),\n      now()\n    FROM generate_series(1, $2::int) AS n\n    ON CONFLICT (id) DO NOTHING\n    `,
    [pwdHash, totalUsers],
  );
  log("public.users", `1..${totalUsers}`);
  await client.query(
    `\n    INSERT INTO public.users (\n      id, username, avatar_url, short_id, coins, diamonds,\n      user_level, charm_level, charm_value, wealth_level, wealth_value,\n      country_code, gender, is_banned, created_at, updated_at\n    )\n    SELECT\n      ('${USER_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      'DemoUser_' || n,\n      'https://i.pravatar.cc/200?img=' || (n % 70),\n      880000 + n,\n      CASE WHEN n <= $2 THEN 500000 + (n % 100000) ELSE 50000 + (n % 50000) END,\n      0,\n      CASE WHEN n <= $2 THEN 10 + (n % 20) ELSE 1 + (n % 15) END,\n      (n % 40) + 1,\n      ((n % 40) + 1) * 1000 + (n % 500),\n      ((n * 7) % 39) + 1,\n      (((n * 7) % 39) + 1) * 5000 + (n % 2000),\n      'PK',\n      CASE WHEN n % 2 = 0 THEN 'female' ELSE 'male' END,\n      false,\n      now(),\n      now()\n    FROM generate_series(1, $1::int) AS n\n    ON CONFLICT (id) DO UPDATE SET\n      username = EXCLUDED.username,\n      avatar_url = EXCLUDED.avatar_url,\n      charm_level = EXCLUDED.charm_level,\n      wealth_level = EXCLUDED.wealth_level,\n      charm_value = EXCLUDED.charm_value,\n      wealth_value = EXCLUDED.wealth_value,\n      updated_at = now()\n    `,
    [totalUsers, agencyCount],
  );
  log("agencies", `1..${agencyCount}`);
  await client.query(
    `\n    INSERT INTO public.agencies (id, owner_id, name, agency_code, is_active, created_at)\n    SELECT\n      ('${AGENCY_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      ('${USER_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      'Demo Agency ' || n,\n      'BK' || lpad(n::text, 5, '0'),\n      true,\n      now()\n    FROM generate_series(1, $1::int) AS n\n    ON CONFLICT (id) DO UPDATE SET\n      name = EXCLUDED.name,\n      agency_code = EXCLUDED.agency_code,\n      is_active = true\n    `,
    [agencyCount],
  );
  log("agency_members", `1..${agencyCount}`);
  await client.query(
    `\n    INSERT INTO public.agency_members (agency_id, user_id, joined_at)\n    SELECT\n      ('${AGENCY_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      ('${USER_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      now()\n    FROM generate_series(1, $1::int) AS n\n    ON CONFLICT DO NOTHING\n    `,
    [agencyCount],
  );
  log("rooms", `1..${agencyCount}`);
  await client.query(
    `\n    INSERT INTO public.rooms (\n      id, host_id, title, image_url, is_active, is_private,\n      country_code, mic_count, room_topic, created_at\n    )\n    SELECT\n      ('${ROOM_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      ('${USER_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      'Demo Room ' || n,\n      'https://picsum.photos/seed/demo-room-' || n || '/400/400',\n      true,\n      false,\n      'PK',\n      8,\n      'chat',\n      now()\n    FROM generate_series(1, $1::int) AS n\n    ON CONFLICT (id) DO UPDATE SET\n      title = EXCLUDED.title,\n      image_url = EXCLUDED.image_url,\n      is_active = true\n    `,
    [agencyCount],
  );
  log("room_stats", `1..${agencyCount}`);
  await client.query(
    `\n    INSERT INTO public.room_stats (room_id, total_exp, hotness_score, current_level, updated_at)\n    SELECT\n      ('${ROOM_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n      GREATEST(1000, 2000000 - n * 150 + (n % 97) * 13)::bigint,\n      GREATEST(1000, 2000000 - n * 150 + (n % 97) * 13)::bigint,\n      1,\n      now()\n    FROM generate_series(1, $1::int) AS n\n    ON CONFLICT (room_id) DO UPDATE SET\n      total_exp = EXCLUDED.total_exp,\n      hotness_score = EXCLUDED.hotness_score,\n      updated_at = now()\n    `,
    [agencyCount],
  );
  log("gift_logs", `${agencyCount} rooms × ${CONTRIBUTORS_PER_ROOM} senders`);
  await client.query(`DELETE FROM public.gift_logs WHERE room_id::text LIKE '${ROOM_PREFIX}-%'`);
  await client.query(
    `\n    INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount, created_at)\n    SELECT\n      ('${USER_PREFIX}-0000-4000-8000-' || lpad(to_hex(\n        $3::int + ((r.n * 17 + c.c) % GREATEST($2::int - $3::int, 1)) + 1\n      ), 12, '0'))::uuid,\n      ('${USER_PREFIX}-0000-4000-8000-' || lpad(to_hex(r.n), 12, '0'))::uuid,\n      $4::uuid,\n      ('${ROOM_PREFIX}-0000-4000-8000-' || lpad(to_hex(r.n), 12, '0'))::uuid,\n      GREATEST(100, (2000000 / c.c) + (r.n % 500))::int,\n      now()\n    FROM generate_series(1, $1::int) AS r(n)\n    CROSS JOIN generate_series(1, $5::int) AS c(c)\n    `,
    [agencyCount, totalUsers, agencyCount, giftId, CONTRIBUTORS_PER_ROOM],
  );
  log("rankings", "gift / charm / room / agency");
  await client.query(
    `\n    DELETE FROM public.gift_rankings WHERE user_id::text LIKE '${USER_PREFIX}-%';\n    DELETE FROM public.charm_rankings WHERE user_id::text LIKE '${USER_PREFIX}-%';\n    DELETE FROM public.room_rankings WHERE room_id::text LIKE '${ROOM_PREFIX}-%';\n    DELETE FROM public.agency_rankings WHERE agency_id::text LIKE '${AGENCY_PREFIX}-%';\n  `,
  );
  for (const period of ["daily", "weekly", "monthly"]) {
    await client.query(
      `\n      INSERT INTO public.gift_rankings (id, user_id, score, rank, ranking_type)\n      SELECT gen_random_uuid(), user_id, total_score, row_number() OVER (ORDER BY total_score DESC), $1\n      FROM (\n        SELECT sender_id AS user_id, SUM(amount)::bigint AS total_score\n        FROM public.gift_logs\n        WHERE sender_id::text LIKE '${USER_PREFIX}-%'\n        GROUP BY sender_id\n        ORDER BY total_score DESC\n        LIMIT 200\n      ) t\n      `,
      [period],
    );
    await client.query(
      `\n      INSERT INTO public.charm_rankings (id, user_id, score, rank, ranking_type)\n      SELECT gen_random_uuid(), id, charm_value, row_number() OVER (ORDER BY charm_value DESC), $1\n      FROM public.users\n      WHERE id::text LIKE '${USER_PREFIX}-%'\n      ORDER BY charm_value DESC\n      LIMIT 200\n      `,
      [period],
    );
    await client.query(
      `\n      INSERT INTO public.room_rankings (id, room_id, score, rank, ranking_type, updated_at)\n      SELECT gen_random_uuid(), room_id, total_exp, row_number() OVER (ORDER BY total_exp DESC), $1, now()\n      FROM public.room_stats\n      WHERE room_id::text LIKE '${ROOM_PREFIX}-%'\n      ORDER BY total_exp DESC\n      LIMIT 200\n      `,
      [period],
    );
    await client.query(
      `\n      INSERT INTO public.agency_rankings (agency_id, score, rank, ranking_type, updated_at)\n      SELECT\n        ('${AGENCY_PREFIX}-0000-4000-8000-' || lpad(to_hex(n), 12, '0'))::uuid,\n        GREATEST(1000, ($2 - n) * 250)::bigint,\n        n,\n        $1,\n        now()\n      FROM generate_series(1, LEAST($2, 200)) AS n\n      `,
      [period, agencyCount],
    );
  }
}

async function main() {
  const env = loadEnv();
  const databaseUrl = env.DATABASE_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL not set in .env.local");
  const totalUsers = Number(env.BULK_DEMO_USERS || 5e4);
  const agencyCount = Number(env.BULK_DEMO_AGENCIES || 1e4);
  const shouldClean = process.argv.includes("--clean");
  if (agencyCount > totalUsers) {
    throw new Error("BULK_DEMO_AGENCIES cannot exceed BULK_DEMO_USERS");
  }
  const client = new Client({
    connectionString: databaseUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const started = Date.now();
  try {
    await client.query("SET statement_timeout = 0");
    if (shouldClean) await cleanBulkDemo(client);
    await client.query("SET session_replication_role = replica");
    const hashRes = await client.query(`SELECT crypt('Demo1234!', gen_salt('bf')) AS h`);
    const pwdHash = hashRes.rows[0].h;
    const giftRes = await client.query(
      `\n      SELECT id FROM public.shop_items\n      WHERE is_gift = true AND is_active = true\n      ORDER BY price_coins ASC\n      LIMIT 1\n    `,
    );
    let giftId = giftRes.rows[0]?.id;
    if (!giftId) {
      const legacy = await client.query(
        `SELECT id FROM public.gifts WHERE is_active = true LIMIT 1`,
      );
      giftId = legacy.rows[0]?.id;
    }
    if (!giftId) throw new Error("No active gift item found in shop_items/gifts");
    await seedBulk(client, totalUsers, agencyCount, pwdHash, giftId);
    await client.query("SET session_replication_role = DEFAULT");
    const summary = await client.query(
      `\n      SELECT\n        (SELECT COUNT(*)::int FROM public.users WHERE id::text LIKE '${USER_PREFIX}-%') AS users,\n        (SELECT COUNT(*)::int FROM public.agencies WHERE id::text LIKE '${AGENCY_PREFIX}-%') AS agencies,\n        (SELECT COUNT(*)::int FROM public.rooms WHERE id::text LIKE '${ROOM_PREFIX}-%') AS rooms,\n        (SELECT COUNT(*)::int FROM public.gift_logs WHERE room_id::text LIKE '${ROOM_PREFIX}-%') AS gift_logs,\n        (SELECT COUNT(*)::int FROM public.gift_rankings WHERE user_id::text LIKE '${USER_PREFIX}-%') AS gift_rank_rows\n    `,
    );
    const s = summary.rows[0];
    const mins = ((Date.now() - started) / 6e4).toFixed(1);
    console.log("\nBulk demo seed completed.");
    console.log(`Users: ${s.users}`);
    console.log(`Agencies: ${s.agencies}`);
    console.log(`Rooms: ${s.rooms}`);
    console.log(`Gift logs: ${s.gift_logs}`);
    console.log(`Gift ranking rows: ${s.gift_rank_rows}`);
    console.log(`Sample room id: ${demoUuid(ROOM_PREFIX, 1)}`);
    console.log(`Elapsed: ${mins} min`);
    console.log(
      "\nSet useRoomContributionMockData = false in app_constants.dart for real DB data.",
    );
  } finally {
    await client.query("SET session_replication_role = DEFAULT").catch(() => {});
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
