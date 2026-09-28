import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

const DEFAULT_RULES = [
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

async function main() {
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("Set DATABASE_URL in .env.local");
  const client = new Client({
    connectionString: connectionString,
  });
  await client.connect();
  try {
    let eventRes = await client.query(
      `\n      SELECT id, title, action_config\n      FROM public.party_events\n      WHERE event_kind = 'game_star_native'\n         OR screen_template = 'game_star'\n      ORDER BY priority DESC, updated_at DESC NULLS LAST\n      LIMIT 1\n    `,
    );
    let eventId;
    if (eventRes.rows.length === 0) {
      const ins = await client.query(
        `\n        INSERT INTO public.party_events (\n          title, subtitle, banner_url, event_kind, screen_template,\n          action_type, action_config, start_at, end_at, is_active, priority, updated_at\n        ) VALUES (\n          'Game Star',\n          'Game King',\n          '',\n          'game_star_native',\n          'game_star',\n          'none',\n          $1::jsonb,\n          now() - interval '21 days',\n          now() + interval '20 days',\n          true,\n          22,\n          now()\n        )\n        RETURNING id, title\n      `,
        [
          JSON.stringify({
            rules: DEFAULT_RULES,
            game_star_game_ids: [],
            reward_slots: {},
          }),
        ],
      );
      eventId = ins.rows[0].id;
      console.log("Created Game Star event:", eventId);
    } else {
      eventId = eventRes.rows[0].id;
      console.log("Using Game Star event:", eventId, eventRes.rows[0].title);
      await client.query(
        `\n        UPDATE public.party_events\n        SET is_active = true,\n            start_at = LEAST(COALESCE(start_at, now()), now() - interval '21 days'),\n            end_at = GREATEST(COALESCE(end_at, now()), now() + interval '20 days'),\n            updated_at = now()\n        WHERE id = $1\n      `,
        [eventId],
      );
    }
    const games = await client.query(
      `\n      SELECT id, name, icon_url\n      FROM public.game_configs\n      WHERE is_active = true\n      ORDER BY sort_order ASC NULLS LAST\n      LIMIT 4\n    `,
    );
    if (games.rows.length === 0) {
      throw new Error("No active game_configs found");
    }
    const gameIds = games.rows.map((g) => g.id);
    console.log(
      "Display games:",
      games.rows.map((g) => g.name),
    );
    const gifts = await client.query(
      `\n      SELECT name, image_url FROM public.shop_items\n      WHERE is_gift = true AND is_active = true\n        AND image_url IS NOT NULL AND image_url <> ''\n      ORDER BY price_coins DESC\n      LIMIT 20\n    `,
    );
    const g = gifts.rows;
    const pick = (i, label) => ({
      label: label,
      image_url: g.length ? g[i % g.length].image_url : "",
    });
    const reward_slots = {
      rank_1: {
        label: "Top 1",
        items: [
          pick(0, "Game Crown x 7d"),
          pick(1, "VIP Frame x 7d"),
          pick(2, "Entry Effect x 7d"),
          pick(3, "Medal TOP1 x 7d"),
          pick(4, "Coins 500K"),
        ],
      },
      rank_2: {
        label: "Top 2",
        items: [
          pick(1, "VIP Frame x 7d"),
          pick(2, "Medal TOP2 x 7d"),
          pick(3, "Coins 250K"),
          pick(4, "Badge x 7d"),
          pick(5, "Frame x 7d"),
        ],
      },
      rank_3: {
        label: "Top 3",
        items: [
          pick(2, "Medal TOP3 x 7d"),
          pick(3, "Coins 150K"),
          pick(4, "Badge x 7d"),
          pick(5, "Frame x 7d"),
          pick(6, "SVIP x 7d"),
        ],
      },
      rank_4_10: {
        label: "Top 4 ~ 10",
        items: [pick(7, "SVIP3 x 7d"), pick(8, "Coins 25K")],
      },
    };
    await client.query(
      `\n      UPDATE public.party_events\n      SET action_config = COALESCE(action_config, '{}'::jsonb)\n        || jsonb_build_object(\n          'rules', COALESCE(NULLIF(action_config->>'rules', ''), $2),\n          'game_star_game_ids', $3::jsonb,\n          'reward_slots', $4::jsonb\n        ),\n        updated_at = now()\n      WHERE id = $1\n    `,
      [eventId, DEFAULT_RULES, JSON.stringify(gameIds), JSON.stringify(reward_slots)],
    );
    const users = await client.query(
      `\n      SELECT id, username, short_id\n      FROM public.users\n      WHERE username IS NOT NULL\n      ORDER BY created_at DESC NULLS LAST\n      LIMIT 22\n    `,
    );
    if (users.rows.length < 5) {
      throw new Error("Need at least 5 users in public.users");
    }
    console.log("Users for mock:", users.rows.length);
    const weekStartRes = await client.query(`SELECT date_trunc('week', now()) AS s`);
    const weekStart = weekStartRes.rows[0].s;
    const lastWeekStartRes = await client.query(
      `SELECT date_trunc('week', now()) - interval '1 week' AS s`,
    );
    const lastWeekStart = lastWeekStartRes.rows[0].s;
    await client.query(
      `\n      DELETE FROM public.transactions\n      WHERE transaction_type = 'game_win'\n        AND description = 'game_star_mock'\n    `,
    );
    async function seedWin(userId, amount, at, gameId) {
      await client.query(
        `\n        INSERT INTO public.transactions (\n          user_id, amount, currency_type, transaction_type,\n          description, reference_id, created_at\n        ) VALUES (\n          $1, $2, 'coin', 'game_win',\n          'game_star_mock', $3::uuid, $4::timestamptz\n        )\n      `,
        [userId, amount, gameId, at],
      );
    }
    const nowIso = new Date().toISOString();
    const lastWeekAt = new Date(
      new Date(lastWeekStart).getTime() + 3 * 24 * 3600 * 1e3,
    ).toISOString();
    const twoWeeksAgo = new Date(
      new Date(weekStart).getTime() - 14 * 24 * 3600 * 1e3 + 3 * 24 * 3600 * 1e3,
    ).toISOString();
    const thisWeekBase = [
      92e3, 78e3, 61e3, 5e4, 42e3, 35e3, 28e3, 22e3, 16e3, 12e3, 9e3, 6500, 4e3, 2500, 1200,
    ];
    const lastWeekBase = [85e3, 67e3, 48e3, 36e3, 25e3, 18e3, 11e3, 7e3];
    const histBase = [55e3, 4e4, 28e3, 15e3, 8e3];
    for (let gi = 0; gi < gameIds.length; gi++) {
      const gameId = gameIds[gi];
      const bump = gi * 700;
      for (let i = 0; i < thisWeekBase.length && i < users.rows.length; i++) {
        const ui = (i + gi) % users.rows.length;
        await seedWin(users.rows[ui].id, thisWeekBase[i] - bump, nowIso, gameId);
      }
      for (let i = 0; i < lastWeekBase.length && i < users.rows.length; i++) {
        const ui = (i + gi + 3) % users.rows.length;
        await seedWin(users.rows[ui].id, lastWeekBase[i] - bump, lastWeekAt, gameId);
      }
      for (let i = 0; i < histBase.length && i < users.rows.length; i++) {
        const ui = (i + gi + 1) % users.rows.length;
        await seedWin(users.rows[ui].id, histBase[i] - bump, twoWeeksAgo, gameId);
      }
      console.log("Seeded game", gi + 1, "/", gameIds.length, gameId);
    }
    await client.query(`SELECT public.refresh_game_star_rankings($1)`, [eventId]);
    for (const gid of gameIds) {
      const per = await client.query(
        `SELECT rank, score, username FROM get_game_star_rankings($1, 'current', 5, 0, $2::uuid)`,
        [eventId, gid],
      );
      console.log("Per-game current top", gid.slice(0, 8), per.rows);
    }
    const current = await client.query(
      `\n      SELECT rank, score, u.username\n      FROM public.game_star_rankings r\n      JOIN public.users u ON u.id = r.user_id\n      WHERE r.party_event_id = $1 AND r.period_key = 'current'\n      ORDER BY r.rank\n      LIMIT 10\n    `,
      [eventId],
    );
    const last = await client.query(
      `\n      SELECT rank, score, u.username\n      FROM public.game_star_rankings r\n      JOIN public.users u ON u.id = r.user_id\n      WHERE r.party_event_id = $1 AND r.period_key = 'last'\n      ORDER BY r.rank\n      LIMIT 5\n    `,
      [eventId],
    );
    console.log("Aggregate this week top:", current.rows);
    console.log("Aggregate last week top:", last.rows);
    console.log("Done. Open Game Star and tap each game.");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
