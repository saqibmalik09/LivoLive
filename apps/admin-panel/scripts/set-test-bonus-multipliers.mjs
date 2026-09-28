import pg from "pg";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
const { Client } = pg;
const envPath = join(dirname(fileURLToPath(import.meta.url)), "..", ".env.local");
const env = {};
for (const line of readFileSync(envPath, "utf8").split("\n")) {
  const m = line.match(/^([^#=]+)=(.*)$/);
  if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
}
const c = new Client({
  connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL,
  ssl: { rejectUnauthorized: false },
});
await c.connect();
await c.query(`
  UPDATE lucky_pro_gift_config
  SET bonus_multiplier_min = 10, bonus_multiplier_max = 100, updated_at = now()
  WHERE id = 1
`);
await c.query(`
  UPDATE lucky_gift_config
  SET bonus_multiplier_min = 10, bonus_multiplier_max = 50, updated_at = now()
  WHERE id = 1
`);
const pro = await c.query(
  "SELECT bonus_multiplier_min, bonus_multiplier_max FROM lucky_pro_gift_config WHERE id=1",
);
const lucky = await c.query(
  "SELECT bonus_multiplier_min, bonus_multiplier_max FROM lucky_gift_config WHERE id=1",
);
console.log("pro", pro.rows[0]);
console.log("lucky", lucky.rows[0]);
await c.end();
