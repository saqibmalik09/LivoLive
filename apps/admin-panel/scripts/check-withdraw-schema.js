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
  const agencies = await client.query(
    `\n    SELECT column_name FROM information_schema.columns\n    WHERE table_schema='public' AND table_name='agencies'\n      AND column_name IN ('owner_id','is_active')\n  `,
  );
  console.log("agencies cols:", agencies.rows);
  const ref = await client.query(
    `\n    SELECT data_type FROM information_schema.columns\n    WHERE table_schema='public' AND table_name='transactions'\n      AND column_name='reference_id'\n  `,
  );
  console.log("reference_id:", ref.rows);
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
