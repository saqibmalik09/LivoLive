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
    "20260717210000_hierarchy_policy_exact.sql",
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
  const checks = await client.query(
    `\n    SELECT 'agency_salary_level_configs' AS t, COUNT(*)::text AS n FROM agency_salary_level_configs\n    UNION ALL\n    SELECT 'bd_level_configs', COUNT(*)::text FROM bd_level_configs\n    UNION ALL\n    SELECT 'host_pc', host_pc::text FROM commission_configs WHERE id = 1\n    UNION ALL\n    SELECT 'county_admin_roles', COUNT(*)::text FROM business_staff WHERE role = 'county_admin'\n  `,
  );
  console.log(checks.rows);
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
