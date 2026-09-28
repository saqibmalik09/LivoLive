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

const SQL = `\nCREATE OR REPLACE FUNCTION public.open_room_reward_box(\n  p_room_id uuid,\n  p_level integer\n)\nRETURNS json\nLANGUAGE plpgsql\nSECURITY DEFINER\nSET search_path TO public\nAS $function$\nDECLARE\n  v_user_id uuid := auth.uid();\n  v_energy bigint := 0;\n  v_required bigint;\n  v_item public.room_reward_items%ROWTYPE;\n  v_total_weight integer;\n  v_pick integer;\n  v_running integer := 0;\n  v_claim_id uuid;\n  v_expires timestamptz;\n  v_snapshot jsonb;\n  v_duration integer;\nBEGIN\n  IF v_user_id IS NULL THEN\n    RETURN json_build_object('success', false, 'message', 'Not authenticated');\n  END IF;\n\n  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 OR p_level > 5 THEN\n    RETURN json_build_object('success', false, 'message', 'Invalid params');\n  END IF;\n\n  IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN\n    RETURN json_build_object('success', false, 'message', 'Room not found');\n  END IF;\n\n  SELECT l.required_points\n  INTO v_required\n  FROM public.room_reward_levels l\n  WHERE l.level = p_level\n    AND l.is_active = true;\n\n  IF NOT FOUND THEN\n    RETURN json_build_object('success', false, 'message', 'Level not found');\n  END IF;\n\n  IF EXISTS (\n    SELECT 1\n    FROM public.room_reward_claims c\n    WHERE c.user_id = v_user_id\n      AND c.room_id = p_room_id\n      AND c.level = p_level\n  ) THEN\n    RETURN json_build_object('success', false, 'message', 'Already claimed');\n  END IF;\n\n  SELECT COALESCE(SUM(gl.amount), 0)::bigint\n  INTO v_energy\n  FROM public.gift_logs gl\n  WHERE gl.room_id = p_room_id\n    AND gl.sender_id = v_user_id;\n\n  IF v_energy < v_required THEN\n    RETURN json_build_object(\n      'success', false,\n      'message', 'Not enough energy',\n      'energy', v_energy,\n      'required', v_required\n    );\n  END IF;\n\n  SELECT COALESCE(SUM(i.weight), 0)\n  INTO v_total_weight\n  FROM public.room_reward_items i\n  WHERE i.level = p_level\n    AND i.is_active = true;\n\n  IF v_total_weight <= 0 THEN\n    RETURN json_build_object('success', false, 'message', 'No rewards configured');\n  END IF;\n\n  v_pick := 1 + floor(random() * v_total_weight)::integer;\n\n  FOR v_item IN\n    SELECT *\n    FROM public.room_reward_items i\n    WHERE i.level = p_level\n      AND i.is_active = true\n    ORDER BY i.sort_order, i.created_at\n  LOOP\n    v_running := v_running + v_item.weight;\n    IF v_running >= v_pick THEN\n      EXIT;\n    END IF;\n  END LOOP;\n\n  IF v_item.id IS NULL THEN\n    RETURN json_build_object('success', false, 'message', 'Reward pick failed');\n  END IF;\n\n  v_snapshot := jsonb_build_object(\n    'id', v_item.id,\n    'title', v_item.title,\n    'image_url', v_item.image_url,\n    'reward_type', v_item.reward_type,\n    'coin_amount', v_item.coin_amount,\n    'shop_item_id', v_item.shop_item_id,\n    'level', p_level\n  );\n\n  IF v_item.reward_type = 'coins' AND v_item.coin_amount > 0 THEN\n    UPDATE public.users\n    SET coins = coins + v_item.coin_amount\n    WHERE id = v_user_id;\n\n    INSERT INTO public.transactions (\n      user_id, amount, currency_type, transaction_type, reference_id\n    ) VALUES (\n      v_user_id,\n      v_item.coin_amount,\n      'coin',\n      'room_reward',\n      p_room_id\n    );\n  ELSIF v_item.reward_type = 'shop_item' AND v_item.shop_item_id IS NOT NULL THEN\n    SELECT COALESCE(si.duration_days, 0)\n    INTO v_duration\n    FROM public.shop_items si\n    WHERE si.id = v_item.shop_item_id\n      AND si.is_active = true;\n\n    IF NOT FOUND THEN\n      RETURN json_build_object('success', false, 'message', 'Shop item missing');\n    END IF;\n\n    v_expires := CASE\n      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)\n      ELSE '9999-12-31'::timestamptz\n    END;\n\n    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)\n    VALUES (v_user_id, v_item.shop_item_id, 'room_reward', v_expires)\n    ON CONFLICT (user_id, item_id) DO NOTHING;\n  END IF;\n\n  INSERT INTO public.room_reward_claims (\n    user_id, room_id, level, reward_item_id, reward_snapshot\n  ) VALUES (\n    v_user_id, p_room_id, p_level, v_item.id, v_snapshot\n  )\n  RETURNING id INTO v_claim_id;\n\n  RETURN json_build_object(\n    'success', true,\n    'claim_id', v_claim_id,\n    'reward', v_snapshot\n  );\nEXCEPTION\n  WHEN unique_violation THEN\n    RETURN json_build_object('success', false, 'message', 'Already claimed');\n  WHEN others THEN\n    RETURN json_build_object(\n      'success', false,\n      'message', SQLERRM\n    );\nEND;\n$function$;\n`;

async function main() {
  const env = loadEnv();
  const cs = env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!cs) throw new Error("DATABASE_URL required");
  const client = new Client({
    connectionString: cs,
  });
  await client.connect();
  try {
    const col = await client.query(
      `SELECT column_name FROM information_schema.columns\n       WHERE table_schema='public' AND table_name='shop_items'\n         AND column_name='duration_days'`,
    );
    console.log("duration_days?", col.rows.length > 0);
    await client.query(SQL);
    console.log("open_room_reward_box updated");
    await client.query("BEGIN");
    try {
      await client.query(
        `INSERT INTO public.transactions\n           (user_id, amount, currency_type, transaction_type, reference_id)\n         VALUES ($1, 1, 'coin', 'room_reward', $2)`,
        ["558c2134-9425-46bc-aac0-23f06d462492", "af18a907-62e6-4d6d-bc70-0d80920d9b27"],
      );
      console.log("TX_UUID_OK");
    } catch (e) {
      console.log("TX_UUID_FAIL", e.message);
    }
    await client.query("ROLLBACK");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
