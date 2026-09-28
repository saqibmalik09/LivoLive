import pg from "pg";
import { readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
const { Client } = pg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = join(__dirname, "..", ".env.local");
const sqlPath = join(
  __dirname,
  "..",
  "..",
  "sk_live",
  "supabase",
  "migrations",
  "20250712150000_cp_nest_proposal_rpcs.sql",
);
function loadEnv() {
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}
const env = loadEnv();
const url = env.DATABASE_URL || env.SUPABASE_DB_URL || env.POSTGRES_URL;
if (!url) {
  console.error("No DB URL found in .env.local");
  process.exit(1);
}
const sql = readFileSync(sqlPath, "utf8");
const client = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await client.connect();
const cfg = await client.query(`
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'cp_configs'
  ) AS ok
`);
if (!cfg.rows[0].ok) {
  console.log("Creating empty cp_configs (missing)...");
  await client.query(`
    CREATE TABLE IF NOT EXISTS public.cp_configs (
      key text PRIMARY KEY,
      value jsonb NOT NULL DEFAULT '{}'::jsonb
    );
  `);
}
console.log("Applying CP Nest proposal RPCs...");
await client.query(sql);
console.log("Done. Verifying functions...");
const funcs = await client.query(`
  SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('send_cp_proposal', 'respond_to_cp_proposal', 'breakup_couple')
  ORDER BY 1
`);
console.log(JSON.stringify(funcs.rows, null, 2));
await client.end();
