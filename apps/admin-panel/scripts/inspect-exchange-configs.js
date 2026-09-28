const { Client: Client } = require("pg");

const fs = require("fs");

const path = require("path");

function loadEnv() {
  const env = fs.readFileSync(path.join(__dirname, "..", ".env.local"), "utf8");
  const get = (k) => {
    const m = env.match(new RegExp(`^${k}=(.*)$`, "m"));
    if (!m) return "";
    return m[1].trim().replace(/^["']|["']$/g, "");
  };
  return get("DATABASE_URL");
}

async function main() {
  const client = new Client({
    connectionString: loadEnv(),
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const { rows: rows } = await client.query(
    `SELECT id, from_currency, to_currency, rate, min_amount, is_active FROM exchange_configs ORDER BY created_at`,
  );
  console.log(JSON.stringify(rows, null, 2));
  const cols = await client.query(
    `\n    SELECT column_name FROM information_schema.columns\n    WHERE table_name='exchange_configs' ORDER BY ordinal_position\n  `,
  );
  console.log(
    "cols",
    cols.rows.map((r) => r.column_name),
  );
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
