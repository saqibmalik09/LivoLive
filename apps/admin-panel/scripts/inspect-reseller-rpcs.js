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
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const { rows: rows } = await client.query(
    `\n    SELECT p.proname, pg_get_function_result(p.oid) AS result,\n           pg_get_function_identity_arguments(p.oid) AS args,\n           pg_get_functiondef(p.oid) AS def\n    FROM pg_proc p\n    JOIN pg_namespace n ON n.oid = p.pronamespace\n    WHERE n.nspname = 'public'\n      AND p.proname IN ('transfer_coins_reseller', 'get_reseller_history')\n  `,
  );
  for (const r of rows) {
    console.log("===", r.proname, "===");
    console.log("result:", r.result);
    console.log("args:", r.args);
    console.log(r.def);
    console.log("\n");
  }
  const { rows: tx } = await client.query(
    `\n    SELECT column_name, data_type, udt_name\n    FROM information_schema.columns\n    WHERE table_schema='public' AND table_name='transactions'\n    ORDER BY ordinal_position\n  `,
  );
  console.log("transactions:", tx);
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
