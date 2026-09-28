import pg from "pg";

import { existsSync, readFileSync } from "fs";

import { dirname, resolve } from "path";

import { spawnSync } from "child_process";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = resolve(__dirname, "..", ".env.local");

const defaultWorkbook = resolve(__dirname, "..", "..", "asstes", "merchantGame_1786704997611.xlsx");

const workbookPath = resolve(process.argv[2] || defaultWorkbook);

const CDN = "https://game-1305970982.cos.ap-singapore.myqcloud.com";

const DOMAIN = "https://gamesp.tulasigame.com/";

const MERCHANT_ID = "1503241";

const PYTHON_XLSX_READER = String.raw`
import json, re, sys
from zipfile import ZipFile
from xml.etree import ElementTree as ET

path = sys.argv[1]
main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
rels_ns = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
ns = {'m': main, 'r': rels_ns}

def col_index(ref):
    letters = re.match(r'[A-Z]+', ref).group(0)
    value = 0
    for ch in letters:
        value = value * 26 + ord(ch) - 64
    return value - 1

with ZipFile(path) as z:
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for item in root.findall('m:si', ns):
            shared.append(''.join(t.text or '' for t in item.iter('{%s}t' % main)))

    workbook = ET.fromstring(z.read('xl/workbook.xml'))
    rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    rel_map = {item.attrib['Id']: item.attrib['Target'] for item in rels}
    sheet = workbook.find('m:sheets', ns)[0]
    target = rel_map[sheet.attrib['{%s}id' % rels_ns]]
    if not target.startswith('xl/'):
        target = 'xl/' + target.lstrip('/')
    root = ET.fromstring(z.read(target))

    parsed = []
    for row in root.findall('.//m:sheetData/m:row', ns):
        cells = {}
        for cell in row.findall('m:c', ns):
            index = col_index(cell.attrib.get('r', 'A1'))
            kind = cell.attrib.get('t')
            value_node = cell.find('m:v', ns)
            inline = cell.find('m:is', ns)
            value = ''
            if kind == 'inlineStr' and inline is not None:
                value = ''.join(t.text or '' for t in inline.iter('{%s}t' % main))
            elif value_node is not None:
                value = value_node.text or ''
                if kind == 's':
                    value = shared[int(value)]
            cells[index] = value
        parsed.append(cells)

headers = parsed[0]
header_by_col = {index: str(value).strip() for index, value in headers.items()}
rows = []
for raw in parsed[1:]:
    row = {header_by_col[index]: value for index, value in raw.items()
           if index in header_by_col}
    if str(row.get('ID', '')).strip():
        rows.append(row)
print(json.dumps(rows, ensure_ascii=False))
`;

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const match = line.match(/^([^#=]+)=(.*)$/);
    if (match) {
      env[match[1].trim()] = match[2].trim().replace(/^["']|["']$/g, "");
    }
  }
  return env;
}

function readWorkbook() {
  if (!existsSync(workbookPath)) {
    throw new Error(`Workbook not found: ${workbookPath}`);
  }
  const result = spawnSync("python3", ["-c", PYTHON_XLSX_READER, workbookPath], {
    encoding: "utf8",
    maxBuffer: 25 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(result.stderr || "Could not read XLSX");
  }
  return JSON.parse(result.stdout);
}

function jsonValue(raw, fallback) {
  const text = String(raw ?? "").trim();
  if (!text) return fallback;
  try {
    return JSON.parse(text);
  } catch {
    return fallback;
  }
}

function publicAsset(path) {
  const value = String(path ?? "").trim();
  if (!value) return null;
  if (/^https?:\/\//i.test(value)) return value;
  return `${CDN}${value.startsWith("/") ? "" : "/"}${value}`;
}

function providerOf(row) {
  return row?.config_data?.provider;
}

async function main() {
  const rows = readWorkbook();
  if (rows.length !== 51) {
    throw new Error(`Expected 51 games, found ${rows.length}`);
  }
  const wrongMerchant = rows.filter((row) => String(row["商户ID"]).trim() !== MERCHANT_ID);
  if (wrongMerchant.length) {
    throw new Error(`Found ${wrongMerchant.length} rows for another merchant`);
  }
  const env = loadEnv();
  const connectionString = env.DATABASE_URL || env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("DATABASE_URL required");
  const client = new Client({
    connectionString: connectionString,
    ssl: connectionString.includes("localhost")
      ? undefined
      : {
          rejectUnauthorized: false,
        },
  });
  await client.connect();
  let inserted = 0;
  let updated = 0;
  let namespaced = 0;
  try {
    await client.query("BEGIN");
    const existingResult = await client.query(
      `\n      SELECT id, slug, is_active, maintenance_mode, category_id, sort_order,\n             webview_height_percent, config_data\n      FROM public.game_configs\n    `,
    );
    const existing = existingResult.rows;
    const bySlug = new Map(existing.map((row) => [row.slug, row]));
    for (let index = 0; index < rows.length; index += 1) {
      const source = rows[index];
      const platformId = String(source.ID).trim();
      const identification = String(source["游戏唯一标识"] ?? "").trim();
      if (!platformId || !identification) continue;
      let slug = identification;
      let owned = bySlug.get(slug);
      if (owned && providerOf(owned) !== "tulasi") {
        slug = `tulasi_${identification}`;
        owned = bySlug.get(slug);
        namespaced += 1;
      }
      const imagePath = String(source["图片"] ?? "").trim();
      const bannerPath = String(source["banner图"] ?? "").trim();
      const status = Number(source["游戏启用状态"] ?? 1);
      const chips = jsonValue(source["筹码金额:json"], []);
      const gameRules = jsonValue(source["游戏配置:json"], {});
      const previousConfig =
        owned?.config_data && typeof owned.config_data === "object" ? owned.config_data : {};
      const isLandscape =
        previousConfig.isLandscape === true ||
        previousConfig.isLandscape === "true" ||
        previousConfig.isLandscape === 1 ||
        previousConfig.isLandscape === "1" ||
        previousConfig.is_landscape === true ||
        previousConfig.is_landscape === "true" ||
        previousConfig.is_landscape === 1 ||
        previousConfig.is_landscape === "1";
      const config = {
        ...previousConfig,
        provider: "tulasi",
        tulasi_game_id: platformId,
        tulasi_merchant_id: MERCHANT_ID,
        tulasi_banner: bannerPath,
        tulasi_image_path: imagePath,
        tulasi_banner_path: bannerPath,
        tulasi_game_domain: DOMAIN,
        tulasi_expiration: String(source["到期日期"] ?? "").trim() || null,
        tulasi_description: String(source["游戏描述"] ?? "").trim(),
        tulasi_game_config: gameRules,
        tulasi_chips: chips,
        isLandscape: isLandscape,
      };
      const gameUrl =
        `${DOMAIN}${identification}/?merchant=${MERCHANT_ID}` +
        `&gameId=${encodeURIComponent(platformId)}`;
      const values = [
        slug,
        String(source["标题"] ?? identification).trim() || identification,
        owned ? owned.is_active : status === 1,
        owned ? owned.maintenance_mode : status !== 1,
        publicAsset(imagePath) || publicAsset(bannerPath),
        gameUrl,
        owned ? owned.sort_order : 510 - index,
        owned ? owned.webview_height_percent : 55,
        config,
        owned?.category_id ?? null,
        chips.length ? Math.min(...chips.map(Number).filter(Number.isFinite)) : 0,
        chips.length ? Math.max(...chips.map(Number).filter(Number.isFinite)) : 0,
      ];
      if (owned) {
        await client.query(
          `\n          UPDATE public.game_configs\n          SET slug = $1, name = $2, is_active = $3, maintenance_mode = $4,\n              icon_url = $5, game_url = $6, sort_order = $7,\n              webview_height_percent = $8, config_data = $9::jsonb,\n              category_id = $10, min_bet = $11, max_bet = $12\n          WHERE id = $13\n          `,
          [...values, owned.id],
        );
        updated += 1;
      } else {
        const result = await client.query(
          `\n          INSERT INTO public.game_configs (\n            slug, name, is_active, maintenance_mode, icon_url, game_url,\n            sort_order, webview_height_percent, config_data, category_id,\n            min_bet, max_bet\n          )\n          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10, $11, $12)\n          RETURNING id, slug, is_active, maintenance_mode, category_id,\n                    sort_order, webview_height_percent, config_data\n          `,
          values,
        );
        bySlug.set(slug, result.rows[0]);
        inserted += 1;
      }
    }
    await client.query(
      `\n      INSERT INTO public.system_settings (key, value, description)\n      VALUES (\n        'tulasi_merchant_id',\n        $1,\n        'Tulasi merchant id. Used in game launch URLs.'\n      )\n      ON CONFLICT (key) DO UPDATE SET\n        value = EXCLUDED.value,\n        description = EXCLUDED.description\n      `,
      [MERCHANT_ID],
    );
    const verify = await client.query(
      `\n      SELECT count(*)::int AS count,\n             count(*) FILTER (WHERE is_active)::int AS active,\n             count(*) FILTER (WHERE maintenance_mode)::int AS maintenance\n      FROM public.game_configs\n      WHERE config_data->>'provider' = 'tulasi'\n    `,
    );
    await client.query("COMMIT");
    console.log("workbook_games", rows.length);
    console.log("inserted", inserted);
    console.log("updated", updated);
    console.log("namespaced_collisions", namespaced);
    console.log("admin_tulasi_total", verify.rows[0].count);
    console.log("admin_tulasi_active", verify.rows[0].active);
    console.log("admin_tulasi_maintenance", verify.rows[0].maintenance);
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
