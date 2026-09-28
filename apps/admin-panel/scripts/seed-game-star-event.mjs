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
  "Core Gameplay & Points",
  "• How to Participate: Simply play games during the event period to automatically enter the competition.",
  "• Points Conversion: Every 1 Gold Coin won in-game = 1 Point.",
  "• Calculation Rules: Points are based only on the cumulative Gold Coins won. Coins consumed or lost during gameplay will not be counted or deducted.",
  "",
  "Leaderboard Ranking Rules",
  "• The Ranking tab shows the overall Game Star leaderboard (top players by total win points).",
  "• Higher points rank higher. If points are the same, the player who reached the score first will take the higher rank.",
  "• Rankings update in real time. The final ranking is based on the list at the end of the event.",
  "",
  "Rewards",
  "• Leaderboard Rewards: Players ranked on the Game Star leaderboard will receive exclusive rewards.",
  "• After the overall event concludes, the system will automatically send rewards based on final ranking.",
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
      `SELECT id, title, is_active FROM public.party_events\n       WHERE event_kind = 'game_star_native'\n       ORDER BY updated_at DESC NULLS LAST\n       LIMIT 5`,
    );
    console.log("Existing game star events:", existing.rows);
    if (existing.rows.length > 0) {
      const id = existing.rows[0].id;
      await client.query(
        `UPDATE public.party_events\n         SET is_active = true,\n             title = COALESCE(NULLIF(title, ''), 'Game Star'),\n             subtitle = COALESCE(NULLIF(subtitle, ''), 'Game King'),\n             priority = GREATEST(COALESCE(priority, 0), 12),\n             start_at = COALESCE(start_at, now() - interval '1 day'),\n             end_at = COALESCE(end_at, now() + interval '30 days'),\n             updated_at = now()\n         WHERE id = $1`,
        [id],
      );
      console.log("Activated existing Game Star event:", id);
      return;
    }
    const inserted = await client.query(
      `INSERT INTO public.party_events (\n         title, subtitle, banner_url, event_kind, screen_template,\n         action_type, action_config, start_at, end_at, is_active, priority, updated_at\n       ) VALUES (\n         'Game Star',\n         'Game King',\n         '',\n         'game_star_native',\n         'game_star',\n         'none',\n         $1::jsonb,\n         now() - interval '1 day',\n         now() + interval '30 days',\n         true,\n         12,\n         now()\n       )\n       RETURNING id, title, event_kind`,
      [
        JSON.stringify({
          rules: defaultRules,
          game_star_game_ids: [],
          reward_slots: {},
        }),
      ],
    );
    console.log("Created Game Star event:", inserted.rows[0]);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
