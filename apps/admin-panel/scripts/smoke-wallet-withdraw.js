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
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const { rows: cfg } = await client.query(
    `SELECT fee_percent, min_amount, allowed_days FROM withdrawal_configs WHERE is_active LIMIT 1`,
  );
  console.log("config:", cfg[0]);
  const { rows: merchants } = await client.query(
    `\n    SELECT count(*)::int AS n FROM users WHERE is_reseller IS TRUE\n  `,
  );
  console.log("reseller count:", merchants[0].n);
  const { rows: check } = await client.query(
    `\n    SELECT pg_get_constraintdef(oid) AS def\n    FROM pg_constraint\n    WHERE conname = 'transactions_transaction_type_check'\n  `,
  );
  const def = check[0]?.def || "";
  console.log(
    "has withdrawal_hold:",
    def.includes("withdrawal_hold"),
    "| has cash_exchange_self:",
    def.includes("cash_exchange_self"),
  );
  await client.end();
  console.log("Smoke OK");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
