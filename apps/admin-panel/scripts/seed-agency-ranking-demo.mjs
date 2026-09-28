import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const sqlPath = join(adminRoot, "..", "sk_live", "scripts", "seed-agency-ranking-demo.sql");

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const databaseUrl = env.DATABASE_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL not set in .env.local");
  if (!existsSync(sqlPath)) throw new Error(`Missing SQL file: ${sqlPath}`);
  const sql = readFileSync(sqlPath, "utf8");
  const client = new Client({
    connectionString: databaseUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    await client.query("SET statement_timeout = 0");
    await client.query(sql);
    const counts = await client.query(
      `\n      SELECT ranking_type, COUNT(*)::int AS rows\n      FROM public.agency_rankings\n      GROUP BY ranking_type\n      ORDER BY ranking_type\n    `,
    );
    console.log("Agency rankings seeded:");
    for (const row of counts.rows) {
      console.log(`  ${row.ranking_type}: ${row.rows} rows`);
    }
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
