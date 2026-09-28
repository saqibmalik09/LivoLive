import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

const defaultRules = [
  "1. Only the specified gifts received will be counted for points. All other gifts are invalid.",
  "2. For each specified gift of 1 gold coin received, the recipient can accumulate 1 point of event points.",
  "3. The points are updated in real time. The final ranking is based on the list at the end of the event.",
  "4. After the event ends, the system will automatically send the rewards.",
].join("\n");

async function main() {
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("Set DATABASE_URL in .env.local");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    const existing = await client.query(
      `SELECT id, title, is_active FROM public.party_events\n       WHERE event_kind = 'weekly_star_native'\n       ORDER BY updated_at DESC NULLS LAST\n       LIMIT 5`,
    );
    console.log("Existing weekly star events:", existing.rows);
    if (existing.rows.length > 0) {
      const id = existing.rows[0].id;
      await client.query(
        `UPDATE public.party_events\n         SET is_active = true,\n             title = COALESCE(NULLIF(title, ''), 'Weekly Star'),\n             subtitle = COALESCE(NULLIF(subtitle, ''), 'Shining Star'),\n             priority = GREATEST(COALESCE(priority, 0), 10),\n             start_at = COALESCE(start_at, now() - interval '1 day'),\n             end_at = COALESCE(end_at, now() + interval '30 days'),\n             updated_at = now()\n         WHERE id = $1`,
        [id],
      );
      console.log("Activated existing Weekly Star event:", id);
      return;
    }
    const inserted = await client.query(
      `INSERT INTO public.party_events (\n         title, subtitle, banner_url, event_kind, screen_template,\n         action_type, action_config, start_at, end_at, is_active, priority, updated_at\n       ) VALUES (\n         'Weekly Star',\n         'Shining Star',\n         '',\n         'weekly_star_native',\n         'weekly_star',\n         'none',\n         $1::jsonb,\n         now() - interval '1 day',\n         now() + interval '30 days',\n         true,\n         10,\n         now()\n       )\n       RETURNING id, title, event_kind`,
      [
        JSON.stringify({
          rules: defaultRules,
          weekly_star_gift_ids: [],
          reward_slots: {},
        }),
      ],
    );
    console.log("Created Weekly Star event:", inserted.rows[0]);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
