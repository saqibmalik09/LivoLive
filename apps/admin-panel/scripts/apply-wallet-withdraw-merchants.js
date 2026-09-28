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
    "20260717160000_wallet_withdraw_merchants_records.sql",
  );
  const sql = fs.readFileSync(sqlPath, "utf8");
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  await client.query(sql);
  console.log("Migration applied.");
  const { rows: tables } = await client.query(
    `\n    SELECT table_name\n    FROM information_schema.tables\n    WHERE table_schema = 'public'\n      AND table_name IN (\n        'withdrawal_configs',\n        'user_payment_methods',\n        'wallet_withdrawals'\n      )\n    ORDER BY table_name\n  `,
  );
  console.log(
    "tables:",
    tables.map((r) => r.table_name),
  );
  const { rows: funcs } = await client.query(
    `\n    SELECT proname\n    FROM pg_proc p\n    JOIN pg_namespace n ON n.oid = p.pronamespace\n    WHERE n.nspname = 'public'\n      AND proname IN (\n        'request_cash_withdrawal',\n        'cancel_cash_withdrawal',\n        'admin_process_withdrawal',\n        'get_coin_merchants',\n        'get_wallet_records'\n      )\n    ORDER BY proname\n  `,
  );
  console.log(
    "rpcs:",
    funcs.map((r) => r.proname),
  );
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
