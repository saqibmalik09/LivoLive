import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const sqlPath = join(adminRoot, "..", "sk_live", "scripts", "seed-room-contribution-demo.sql");

const envPath = join(adminRoot, ".env.local");

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
  const databaseUrl = env.DATABASE_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL not set in .env.local");
  if (!existsSync(sqlPath)) throw new Error(`Missing seed SQL: ${sqlPath}`);
  const sql = readFileSync(sqlPath, "utf8");
  const client = new Client({
    connectionString: databaseUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    await client.query(sql);
    const verify = await client.query(
      `\n      SELECT COUNT(*)::int AS users FROM public.users\n      WHERE id::text LIKE 'b1000001-%';\n    `,
    );
    const gifts = await client.query(
      `\n      SELECT COUNT(*)::int AS logs FROM public.gift_logs\n      WHERE room_id = 'b3000001-0001-4001-8001-000000000001';\n    `,
    );
    console.log("Demo seed completed.");
    console.log(`Demo users: ${verify.rows[0].users}`);
    console.log(`Gift logs in demo room: ${gifts.rows[0].logs}`);
    console.log("Demo room id: b3000001-0001-4001-8001-000000000001");
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
