import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

function tier(multiplier) {
  if (multiplier >= 450) return "x500";
  if (multiplier >= 225) return "x250";
  return `x${multiplier}`;
}

async function main() {
  const who = arg("user", "100779");
  const coins = Number(arg("coins", "4800"));
  const mult = Math.max(1, Number(arg("mult", "5")));
  const gameSlug = arg("game", "roulette");
  const env = loadEnv();
  const client = new Client({
    connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    const user = await client.query(
      `SELECT id, short_id, username, avatar_url\n         FROM public.users\n        WHERE short_id::text = $1 OR id::text = $1 OR username ILIKE $1\n        LIMIT 1`,
      [who],
    );
    if (!user.rowCount) throw new Error(`user not found: ${who}`);
    const u = user.rows[0];
    const game = await client.query(
      `SELECT slug, name FROM public.game_configs WHERE slug = $1 LIMIT 1`,
      [gameSlug],
    );
    const label = game.rowCount ? game.rows[0].name : "Game";
    const ins = await client.query(
      `INSERT INTO public.global_win_announcements (\n         user_id, username, avatar_url, source_label, reward_coins,\n         bonus_multiplier, multiplier_tier, variant, game_slug, server_broadcast\n       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'game', $8, true)\n       RETURNING id, created_at`,
      [
        u.id,
        u.username ?? "User",
        u.avatar_url,
        String(label).slice(0, 64),
        coins,
        mult,
        tier(mult),
        game.rowCount ? game.rows[0].slug : null,
      ],
    );
    console.log("patti sent:", {
      user: u.username,
      short_id: u.short_id,
      label: label,
      reward_coins: coins,
      tier: tier(mult),
      ...ins.rows[0],
    });
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
