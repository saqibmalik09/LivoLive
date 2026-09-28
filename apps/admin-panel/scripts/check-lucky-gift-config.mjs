import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const setTest = process.argv.includes("--set-test");

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
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    if (setTest) {
      await client.query(
        `\n        UPDATE public.lucky_gift_config SET\n          gifts_for_bonus_min = 2,\n          gifts_for_bonus_max = 3,\n          bonus_chance_percent = 100,\n          bonus_trigger_mode = 'same_receiver',\n          updated_at = now()\n        WHERE id = 1\n      `,
      );
      await client.query(
        `\n        UPDATE public.lucky_pro_gift_config SET\n          gifts_for_bonus_min = 2,\n          gifts_for_bonus_max = 3,\n          bonus_chance_percent = 100,\n          bonus_trigger_mode = 'same_receiver',\n          updated_at = now()\n        WHERE id = 1\n      `,
      );
      await client.query(
        `TRUNCATE public.lucky_gift_counters, public.lucky_gift_sender_counters RESTART IDENTITY CASCADE`,
      );
      await client.query(
        `\n        DO $$ BEGIN\n          IF to_regclass('public.lucky_pro_gift_counters') IS NOT NULL THEN\n            TRUNCATE public.lucky_pro_gift_counters RESTART IDENTITY CASCADE;\n          END IF;\n          IF to_regclass('public.lucky_pro_gift_sender_counters') IS NOT NULL THEN\n            TRUNCATE public.lucky_pro_gift_sender_counters RESTART IDENTITY CASCADE;\n          END IF;\n        END $$;\n      `,
      );
      console.log(
        "Updated both configs for easy test (2–3 gifts, 100% chance, same_receiver) + counters reset.\n",
      );
    }
    const lucky = await client.query(`SELECT * FROM public.lucky_gift_config WHERE id = 1`);
    const pro = await client.query(`SELECT * FROM public.lucky_pro_gift_config WHERE id = 1`);
    console.log("=== lucky_gift_config ===");
    console.log(JSON.stringify(lucky.rows[0] ?? null, null, 2));
    console.log("\n=== lucky_pro_gift_config ===");
    console.log(JSON.stringify(pro.rows[0] ?? null, null, 2));
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
