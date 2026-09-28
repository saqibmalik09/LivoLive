import pg from "pg";

import { readFileSync, existsSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const CDN = "https://game-1305970982.cos.ap-singapore.myqcloud.com";

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

function loadEnv() {
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

function resolveIcon(raw) {
  const v = String(raw ?? "").trim();
  if (!v) return "";
  if (v.startsWith("http://") || v.startsWith("https://")) return v;
  if (v.startsWith("/")) return `${CDN}${v}`;
  if (v.startsWith("upload/")) return `${CDN}/${v}`;
  return v;
}

async function main() {
  if (!existsSync(envPath)) throw new Error("Missing .env.local");
  const env = loadEnv();
  const cs = env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!cs) throw new Error("DATABASE_URL required");
  const client = new Client({
    connectionString: cs,
    ssl: cs.includes("localhost")
      ? undefined
      : {
          rejectUnauthorized: false,
        },
  });
  await client.connect();
  try {
    const { rows: rows } = await client.query(
      `\n      SELECT id, slug, icon_url,\n             config_data->>'tulasi_image_path' AS image_path,\n             config_data->>'tulasi_banner' AS banner,\n             config_data->>'tulasi_banner_path' AS banner_path\n      FROM game_configs\n      WHERE config_data->>'provider' = 'tulasi'\n         OR game_url ILIKE '%tulasigame.com%'\n    `,
    );
    let n = 0;
    for (const row of rows) {
      const next =
        resolveIcon(row.icon_url) ||
        resolveIcon(row.banner) ||
        resolveIcon(row.image_path) ||
        resolveIcon(row.banner_path);
      if (!next || next === row.icon_url) continue;
      await client.query(`UPDATE game_configs SET icon_url = $1 WHERE id = $2`, [next, row.id]);
      n += 1;
      console.log("fixed", row.slug, next.slice(0, 80));
    }
    console.log("updated", n, "of", rows.length);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
