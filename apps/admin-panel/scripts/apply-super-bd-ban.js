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
    "20260717211000_super_bd_ban_subtree.sql",
  );
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  await client.query(fs.readFileSync(sqlPath, "utf8"));
  console.log("super_bd_set_user_banned applied");
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
