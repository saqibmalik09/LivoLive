-- Fix open_room_reward_box: transactions.reference_id is uuid (not text).
-- Also return clear SQLERRM on unexpected failures.

CREATE OR REPLACE FUNCTION public.open_room_reward_box(
  p_room_id uuid,
  p_level integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_energy bigint := 0;
  v_required bigint;
  v_item public.room_reward_items%ROWTYPE;
  v_total_weight integer;
  v_pick integer;
  v_running integer := 0;
  v_claim_id uuid;
  v_expires timestamptz;
  v_snapshot jsonb;
  v_duration integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 OR p_level > 5 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid params');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  SELECT l.required_points
  INTO v_required
  FROM public.room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
      AND c.level = p_level
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  END IF;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_energy
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.sender_id = v_user_id;

  IF v_energy < v_required THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Not enough energy',
      'energy', v_energy,
      'required', v_required
    );
  END IF;

  SELECT COALESCE(SUM(i.weight), 0)
  INTO v_total_weight
  FROM public.room_reward_items i
  WHERE i.level = p_level
    AND i.is_active = true;

  IF v_total_weight <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No rewards configured');
  END IF;

  v_pick := 1 + floor(random() * v_total_weight)::integer;

  FOR v_item IN
    SELECT *
    FROM public.room_reward_items i
    WHERE i.level = p_level
      AND i.is_active = true
    ORDER BY i.sort_order, i.created_at
  LOOP
    v_running := v_running + v_item.weight;
    IF v_running >= v_pick THEN
      EXIT;
    END IF;
  END LOOP;

  IF v_item.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Reward pick failed');
  END IF;

  v_snapshot := jsonb_build_object(
    'id', v_item.id,
    'title', v_item.title,
    'image_url', v_item.image_url,
    'reward_type', v_item.reward_type,
    'coin_amount', v_item.coin_amount,
    'shop_item_id', v_item.shop_item_id,
    'level', p_level
  );

  IF v_item.reward_type = 'coins' AND v_item.coin_amount > 0 THEN
    UPDATE public.users
    SET coins = coins + v_item.coin_amount
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id,
      v_item.coin_amount,
      'coin',
      'room_reward',
      p_room_id
    );
  ELSIF v_item.reward_type = 'shop_item' AND v_item.shop_item_id IS NOT NULL THEN
    SELECT COALESCE(si.duration_days, 0)
    INTO v_duration
    FROM public.shop_items si
    WHERE si.id = v_item.shop_item_id
      AND si.is_active = true;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Shop item missing');
    END IF;

    v_expires := CASE
      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
      ELSE '9999-12-31'::timestamptz
    END;

    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
    VALUES (v_user_id, v_item.shop_item_id, 'room_reward', v_expires)
    ON CONFLICT (user_id, item_id) DO NOTHING;
  END IF;

  INSERT INTO public.room_reward_claims (
    user_id, room_id, level, reward_item_id, reward_snapshot
  ) VALUES (
    v_user_id, p_room_id, p_level, v_item.id, v_snapshot
  )
  RETURNING id INTO v_claim_id;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'reward', v_snapshot
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  WHEN others THEN
    RETURN json_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$function$;
