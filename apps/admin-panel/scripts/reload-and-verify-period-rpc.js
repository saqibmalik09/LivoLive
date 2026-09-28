const { Client: Client } = require("pg");

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
    dbUrl: get("DATABASE_URL"),
  };
}

async function main() {
  const { url: url, key: key, dbUrl: dbUrl } = loadEnv();
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const { rows: rows } = await client.query(
    `\n    SELECT p.proname, p.provolatile,\n           CASE p.provolatile WHEN 'i' THEN 'IMMUTABLE' WHEN 's' THEN 'STABLE' WHEN 'v' THEN 'VOLATILE' END AS vol\n    FROM pg_proc p\n    JOIN pg_namespace n ON n.oid = p.pronamespace\n    WHERE n.nspname = 'public'\n      AND p.proname IN ('get_current_period_info', 'ensure_salary_period')\n  `,
  );
  console.log("Function volatility:", rows);
  await client.query(
    `\nDROP FUNCTION IF EXISTS public.get_current_period_info();\n\nCREATE OR REPLACE FUNCTION public.ensure_salary_period(p_period_id text)\nRETURNS void\nLANGUAGE plpgsql\nVOLATILE\nSECURITY DEFINER\nSET search_path TO public\nAS $function$\nDECLARE\n    b record;\nBEGIN\n    SELECT * INTO b FROM public.get_period_bounds(p_period_id);\n    INSERT INTO public.salary_periods (period_id, start_date, end_date, payout_date, status)\n    VALUES (p_period_id, b.start_date, b.end_date, b.payout_date, 'open')\n    ON CONFLICT (period_id) DO NOTHING;\nEND;\n$function$;\n\nCREATE FUNCTION public.get_current_period_info()\nRETURNS json\nLANGUAGE plpgsql\nVOLATILE\nSECURITY DEFINER\nSET search_path TO public\nAS $function$\nDECLARE\n    v_period_id text;\n    b record;\nBEGIN\n    v_period_id := public.get_period_id_for_date(current_date);\n    PERFORM public.ensure_salary_period(v_period_id);\n    SELECT * INTO b FROM public.get_period_bounds(v_period_id);\n    RETURN json_build_object(\n        'period_id', v_period_id,\n        'start_date', b.start_date,\n        'end_date', b.end_date,\n        'payout_date', b.payout_date\n    );\nEND;\n$function$;\n\nGRANT EXECUTE ON FUNCTION public.get_current_period_info() TO authenticated;\nGRANT EXECUTE ON FUNCTION public.get_current_period_info() TO anon;\nGRANT EXECUTE ON FUNCTION public.get_current_period_info() TO service_role;\n\nNOTIFY pgrst, 'reload schema';\n`,
  );
  const { rows: afterRows } = await client.query(
    `\n    SELECT p.proname,\n           CASE p.provolatile WHEN 'i' THEN 'IMMUTABLE' WHEN 's' THEN 'STABLE' WHEN 'v' THEN 'VOLATILE' END AS vol\n    FROM pg_proc p\n    JOIN pg_namespace n ON n.oid = p.pronamespace\n    WHERE n.nspname = 'public'\n      AND p.proname IN ('get_current_period_info', 'ensure_salary_period')\n  `,
  );
  console.log("After recreate:", afterRows);
  const { rows: direct } = await client.query(`SELECT public.get_current_period_info() AS info`);
  console.log("Direct SQL call:", direct[0]?.info);
  await client.end();
  await new Promise((r) => setTimeout(r, 2e3));
  const sb = createClient(url, key, {
    auth: {
      persistSession: false,
    },
  });
  const { data: data, error: error } = await sb.rpc("get_current_period_info");
  console.log("PostgREST RPC:", data, error?.message || "ok");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
