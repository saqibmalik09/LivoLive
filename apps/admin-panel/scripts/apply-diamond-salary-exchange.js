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
    "20260717170000_diamond_salary_exchange.sql",
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
  const { rows: rows } = await client.query(
    `SELECT diamonds_unit, usd_per_unit FROM diamond_salary_configs WHERE is_active LIMIT 1`,
  );
  console.log("config:", rows[0]);
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
