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
    "20260717180000_agency_center_menu.sql",
  );
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  await client.query(fs.readFileSync(sqlPath, "utf8"));
  console.log("Migration applied.");
  const { rows: rows } = await client.query(
    `\n    SELECT column_name FROM information_schema.columns\n    WHERE table_name='agency_members' AND column_name='role'\n    UNION ALL\n    SELECT column_name FROM information_schema.columns\n    WHERE table_name='agencies' AND column_name='announcement'\n    UNION ALL\n    SELECT 'agency_notices' WHERE EXISTS (\n      SELECT 1 FROM information_schema.tables WHERE table_name='agency_notices'\n    )\n  `,
  );
  console.log(rows);
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
