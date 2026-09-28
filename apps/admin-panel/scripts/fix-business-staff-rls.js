const fs = require("fs");

const path = require("path");

const { Client: Client } = require("pg");

function loadEnv() {
  const p = path.join(__dirname, "..", ".env.local");
  const env = fs.readFileSync(p, "utf8");
  const get = (k) => {
    const m = env.match(new RegExp(`^${k}=(.*)$`, "m"));
    if (!m) return "";
    return m[1].trim().replace(/^["']|["']$/g, "");
  };
  return get("DATABASE_URL");
}

async function main() {
  const connectionString = loadEnv();
  if (!connectionString) throw new Error("DATABASE_URL missing");
  const sqlPath = path.join(
    __dirname,
    "..",
    "..",
    "sk_live",
    "supabase",
    "migrations",
    "20260717120000_fix_business_staff_rls_recursion.sql",
  );
  const sql = fs.readFileSync(sqlPath, "utf8");
  const client = new Client({
    connectionString: connectionString,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    await client.query(sql);
    console.log("Applied business_staff RLS fix OK");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
