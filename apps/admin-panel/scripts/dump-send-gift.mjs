import pg from "pg";
import { readFileSync, existsSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
const { Client } = pg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = join(__dirname, "..", ".env.local");
const outPath = join(__dirname, "send_gift_live.sql");
function loadEnv() {
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}
const env = loadEnv();
const client = new Client({
  connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL,
  ssl: { rejectUnauthorized: false },
});
await client.connect();
const r = await client.query(`
  SELECT pg_get_functiondef(p.oid) AS def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'send_gift'
  ORDER BY p.oid DESC
  LIMIT 1
`);
writeFileSync(outPath, r.rows[0]?.def ?? "-- none");
console.log("Wrote", outPath, "chars", (r.rows[0]?.def ?? "").length);
const r2 = await client.query(`
  SELECT proname FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND proname ILIKE '%gift%bonus%' OR proname ILIKE '%process_gift%'
`);
console.log("bonus-related funcs", r2.rows);
await client.end();
