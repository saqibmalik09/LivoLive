import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const RULES = [
  "Core Gameplay & Points",
  "• How to Participate: Simply play the designated games (shown on this event screen) during the event period to automatically enter the competition.",
  "• Points Conversion: Every 1 Gold Coin won in a designated game = 1 Point.",
  "• Calculation Rules: Points are based only on Gold Coins won in the admin-selected games. Wins from other games, and coins consumed or lost, will not be counted or deducted.",
  "",
  "Leaderboard Ranking Rules",
  "• The Ranking tab shows the overall Game Star leaderboard from designated-game wins only.",
  "• Higher points rank higher. If points are the same, the player who reached the score first will take the higher rank.",
  "• Rankings update in real time. The final ranking is based on the list at the end of the event.",
  "",
  "Rewards",
  "• Leaderboard Rewards: Players ranked on the Game Star leaderboard will receive exclusive rewards.",
  "• After the overall event concludes, the system will automatically send rewards based on final ranking.",
].join("\n");

function loadEnv() {
  const envPath = join(__dirname, "..", ".env.local");
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
  const client = new Client({
    connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL,
  });
  await client.connect();
  try {
    const res = await client.query(
      `\n      UPDATE public.party_events\n      SET action_config = COALESCE(action_config, '{}'::jsonb)\n            || jsonb_build_object('rules', $1::text),\n          updated_at = now()\n      WHERE event_kind = 'game_star_native'\n      RETURNING id, title\n    `,
      [RULES],
    );
    console.log("Updated rules on", res.rowCount, "event(s):", res.rows);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
