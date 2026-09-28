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
    "20260717190000_agency_info_fields.sql",
  );
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  await client.query(fs.readFileSync(sqlPath, "utf8"));
  const { rows: rows } = await client.query(
    `\n    SELECT column_name FROM information_schema.columns\n    WHERE table_schema='public' AND table_name='agencies'\n      AND column_name IN ('attribute','whatsapp','contact_email','logo_url','announcement','name')\n    ORDER BY column_name\n  `,
  );
  console.log("OK columns:", rows.map((r) => r.column_name).join(", "));
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
