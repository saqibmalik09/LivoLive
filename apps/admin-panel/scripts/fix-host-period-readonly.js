const { createClient: createClient } = require("@supabase/supabase-js");

const fs = require("fs");

const path = require("path");

function loadEnv() {
  const p = path.join(__dirname, "..", ".env.local");
  const env = fs.readFileSync(p, "utf8");
  const get = (k) => {
    const m = env.match(new RegExp(`^${k}=(.*)$`, "m"));
    if (!m) return "";
    return m[1].trim().replace(/^["']|["']$/g, "");
  };
  return {
    url: get("NEXT_PUBLIC_SUPABASE_URL"),
    key: get("SUPABASE_SERVICE_ROLE_KEY"),
    dbUrl: get("DATABASE_URL") || get("SUPABASE_DB_URL") || get("POSTGRES_URL") || "",
  };
}

function periodIdForDate(d = new Date()) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padLeft
    ? String(d.getUTCMonth() + 1).padStart(2, "0")
    : String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = d.getUTCDate();
  return day <= 15 ? `${y}-${m}-A` : `${y}-${m}-B`;
}

async function main() {
  const { url: url, key: key, dbUrl: dbUrl } = loadEnv();
  if (!url || !key) throw new Error("Missing Supabase env");
  const sb = createClient(url, key, {
    auth: {
      persistSession: false,
    },
  });
  const { data: before, error: beforeErr } = await sb.rpc("get_current_period_info");
  console.log("Before RPC:", before, beforeErr?.message || beforeErr || "ok");
  const sql = `\nCREATE OR REPLACE FUNCTION public.ensure_salary_period(p_period_id text)\nRETURNS void\nLANGUAGE plpgsql\nVOLATILE\nSECURITY DEFINER\nSET search_path TO public\nAS $function$\nDECLARE\n    b record;\nBEGIN\n    SELECT * INTO b FROM public.get_period_bounds(p_period_id);\n    INSERT INTO public.salary_periods (period_id, start_date, end_date, payout_date, status)\n    VALUES (p_period_id, b.start_date, b.end_date, b.payout_date, 'open')\n    ON CONFLICT (period_id) DO NOTHING;\nEND;\n$function$;\n\nCREATE OR REPLACE FUNCTION public.get_current_period_info()\nRETURNS json\nLANGUAGE plpgsql\nVOLATILE\nSECURITY DEFINER\nSET search_path TO public\nAS $function$\nDECLARE\n    v_period_id text;\n    b record;\nBEGIN\n    v_period_id := public.get_period_id_for_date(current_date);\n    PERFORM public.ensure_salary_period(v_period_id);\n    SELECT * INTO b FROM public.get_period_bounds(v_period_id);\n    RETURN json_build_object(\n        'period_id', v_period_id,\n        'start_date', b.start_date,\n        'end_date', b.end_date,\n        'payout_date', b.payout_date\n    );\nEND;\n$function$;\n\nGRANT EXECUTE ON FUNCTION public.get_current_period_info() TO authenticated;\nGRANT EXECUTE ON FUNCTION public.get_current_period_info() TO service_role;\n`;
  if (dbUrl) {
    let pg;
    try {
      pg = require("pg");
    } catch {
      console.log("pg not installed, trying npx...");
    }
    if (pg) {
      const client = new pg.Client({
        connectionString: dbUrl,
        ssl: {
          rejectUnauthorized: false,
        },
      });
      await client.connect();
      await client.query(sql);
      await client.end();
      console.log("Applied SQL via DATABASE_URL");
    }
  } else {
    const attempts = [
      () =>
        sb.rpc("exec_sql", {
          query: sql,
        }),
      () =>
        sb.rpc("exec_sql", {
          sql: sql,
        }),
      () =>
        sb.rpc("execute_sql", {
          query: sql,
        }),
    ];
    let applied = false;
    for (const attempt of attempts) {
      try {
        const { error: error } = await attempt();
        if (!error) {
          applied = true;
          console.log("Applied SQL via RPC helper");
          break;
        }
        console.log("RPC helper failed:", error.message);
      } catch (e) {
        console.log("RPC helper exception:", e.message);
      }
    }
    if (!applied) {
      const periodId = periodIdForDate(new Date());
      console.log("\n=== MANUAL SQL REQUIRED (Supabase SQL Editor) ===\n");
      console.log(sql);
      console.log("\nCurrent period_id hint:", periodId);
      process.exitCode = 2;
      return;
    }
  }
  const { data: after, error: afterErr } = await sb.rpc("get_current_period_info");
  console.log("After RPC:", after, afterErr?.message || afterErr || "ok");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
