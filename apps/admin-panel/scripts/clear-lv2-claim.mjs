import pg from "pg";
import { readFileSync, existsSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
const { Client } = pg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = join(__dirname, "..", ".env.local");
const text = readFileSync(envPath, "utf8");
const env = {};
for (const line of text.split("\n")) {
  const m = line.match(/^([^#=]+)=(.*)$/);
  if (m) env[m[1].trim()] = m[2].trim();
}
const client = new Client({ connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL });
await client.connect();
const userId = "558c2134-9425-46bc-aac0-23f06d462492";
const roomId = "af18a907-62e6-4d6d-bc70-0d80920d9b27";
const del = await client.query(
  `DELETE FROM public.room_reward_claims
   WHERE user_id = $1 AND room_id = $2 AND level = 2
   RETURNING id`,
  [userId, roomId],
);
console.log("deleted claims", del.rows);
const fn = await client.query(`SELECT pg_get_functiondef(p.oid) AS def
   FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE p.proname = 'open_room_reward_box' AND n.nspname = 'public'`);
const def = fn.rows[0]?.def || "";
console.log("uses p_room_id::text?", def.includes("p_room_id::text"));
console.log("has others handler?", def.includes("WHEN others"));
await client.end();
