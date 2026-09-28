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
  "1. Hosts must meet both broadcast time and charm targets to receive rewards.",
  "2. Hosts must manually claim prizes after each activity period.",
  "3. Cycles run from the 1st–15th and 16th–end of each month. Data resets after each cycle.",
  "4. Event dates follow the active party event window in SK Live.",
  "5. Final interpretation belongs to SK Live.",
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
      `SELECT id, title, is_active FROM public.party_events\n       WHERE event_kind = 'sk_host_native'\n       ORDER BY updated_at DESC NULLS LAST\n       LIMIT 5`,
    );
    console.log("Existing SK Host Party events:", existing.rows);
    if (existing.rows.length > 0) {
      const id = existing.rows[0].id;
      await client.query(
        `UPDATE public.party_events\n         SET is_active = true,\n             title = COALESCE(NULLIF(title, ''), 'SK Host Party'),\n             subtitle = COALESCE(NULLIF(subtitle, ''), 'Host Event'),\n             priority = GREATEST(COALESCE(priority, 0), 11),\n             start_at = COALESCE(start_at, now() - interval '1 day'),\n             end_at = COALESCE(end_at, now() + interval '30 days'),\n             action_config = COALESCE(action_config, '{}'::jsonb) || $2::jsonb,\n             updated_at = now()\n         WHERE id = $1`,
        [
          id,
          JSON.stringify({
            rules: defaultRules,
          }),
        ],
      );
      console.log("Activated existing SK Host Party event:", id);
      return;
    }
    const inserted = await client.query(
      `INSERT INTO public.party_events (\n         title, subtitle, banner_url, event_kind, screen_template,\n         action_type, action_config, start_at, end_at, is_active, priority, updated_at\n       ) VALUES (\n         'SK Host Party',\n         'Host Event',\n         '',\n         'sk_host_native',\n         'sk_host_party',\n         'none',\n         $1::jsonb,\n         now() - interval '1 day',\n         now() + interval '30 days',\n         true,\n         11,\n         now()\n       )\n       RETURNING id, title, event_kind`,
      [
        JSON.stringify({
          rules: defaultRules,
          reward_tiers: [],
        }),
      ],
    );
    console.log("Created SK Host Party event:", inserted.rows[0]);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
