const { Client: Client } = require("pg");

const fs = require("fs");

const path = require("path");

function loadEnv() {
  const p = path.join(__dirname, "..", ".env.local");
  const env = fs.readFileSync(p, "utf8");
  const get = (k) => {
    const m = env.match(new RegExp(`^${k}=(.*)$`, "m"));
    if (!m) return "";
    return m[1].trim().replace(/^["']|["']$/g, "");
  };
  return {
    dbUrl: get("DATABASE_URL"),
  };
}

async function main() {
  const { dbUrl: dbUrl } = loadEnv();
  if (!dbUrl) throw new Error("Missing DATABASE_URL");
  const sqlPath = path.join(
    __dirname,
    "..",
    "..",
    "sk_live",
    "supabase",
    "migrations",
    "20260717150000_wallet_reseller_cash_balances.sql",
  );
  const sql = fs.readFileSync(sqlPath, "utf8");
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    const { rows: rows } = await client.query(
      `\n      SELECT pg_get_functiondef(p.oid) AS def\n      FROM pg_proc p\n      JOIN pg_namespace n ON n.oid = p.pronamespace\n      WHERE n.nspname = 'public' AND p.proname = 'transfer_coins_reseller'\n      LIMIT 1\n    `,
    );
    if (rows[0]?.def) {
      console.log("Existing transfer_coins_reseller length:", rows[0].def.length);
    } else {
      console.log("No existing transfer_coins_reseller");
    }
  } catch (e) {
    console.warn("Inspect skipped:", e.message);
  }
  await client.query(sql);
  console.log("Migration applied.");
  const { rows: cols } = await client.query(
    `\n    SELECT column_name, data_type\n    FROM information_schema.columns\n    WHERE table_schema = 'public' AND table_name = 'users'\n      AND column_name IN ('reseller_coins', 'cash_balance', 'is_reseller', 'coins')\n    ORDER BY column_name\n  `,
  );
  console.log("users columns:", cols);
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
