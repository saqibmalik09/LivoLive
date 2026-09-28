import pg from "pg";

import { readFileSync, writeFileSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

const migrationPath = join(
  __dirname,
  "..",
  "..",
  "sk_live",
  "supabase",
  "migrations",
  "20250712131000_transactions_lucky_pro_type.sql",
);

function loadEnv() {
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
  const client = new Client({
    connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    const r = await client.query(
      `\n      SELECT conname, pg_get_constraintdef(oid) AS def\n      FROM pg_constraint\n      WHERE conrelid = 'public.transactions'::regclass\n        AND contype = 'c'\n        AND conname ILIKE '%transaction_type%'\n    `,
    );
    console.log("current:", r.rows[0]?.def);
    const def = r.rows[0]?.def ?? "";
    const existing = [...def.matchAll(/'([^']+)'::text/g)].map((m) => m[1]);
    if (existing.length === 0) {
      throw new Error("Could not parse allowed transaction_type values");
    }
    const needed = ["lucky_gift_bonus", "lucky_pro_gift_bonus"];
    const merged = [...new Set([...existing, ...needed])];
    if (existing.includes("lucky_pro_gift_bonus")) {
      console.log("lucky_pro_gift_bonus already allowed — nothing to do");
      return;
    }
    const sql = `\nALTER TABLE public.transactions\n  DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;\n\nALTER TABLE public.transactions\n  ADD CONSTRAINT transactions_transaction_type_check\n  CHECK (transaction_type = ANY (ARRAY[${merged.map((v) => `'${v}'::text`).join(", ")}]));\n`;
    writeFileSync(migrationPath, `-- Allow Lucky / Lucky Pro bonus transaction types.\n${sql}`);
    console.log("Wrote", migrationPath);
    await client.query(sql);
    console.log("Applied. Allowed types now include:", needed.join(", "));
    const after = await client.query(
      `\n      SELECT pg_get_constraintdef(oid) AS def\n      FROM pg_constraint\n      WHERE conrelid = 'public.transactions'::regclass\n        AND contype = 'c'\n        AND conname = 'transactions_transaction_type_check'\n    `,
    );
    console.log("new:", after.rows[0]?.def);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
