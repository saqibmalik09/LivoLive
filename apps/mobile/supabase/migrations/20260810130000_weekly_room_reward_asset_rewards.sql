-- Weekly Room Reward levels: optional shop asset rewards (not only coins).

ALTER TABLE public.weekly_room_reward_levels
  ADD COLUMN IF NOT EXISTS reward_type text NOT NULL DEFAULT 'coins',
  ADD COLUMN IF NOT EXISTS shop_item_id uuid REFERENCES public.shop_items (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS duration_days integer NULL,
  ADD COLUMN IF NOT EXISTS title text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS image_url text NOT NULL DEFAULT '';

DO $$
BEGIN
  ALTER TABLE public.weekly_room_reward_levels
    DROP CONSTRAINT IF EXISTS weekly_room_reward_levels_reward_type_check;
  ALTER TABLE public.weekly_room_reward_levels
    ADD CONSTRAINT weekly_room_reward_levels_reward_type_check
    CHECK (reward_type IN ('coins', 'shop_item'));
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'reward_type check skipped: %', SQLERRM;
END $$;

ALTER TABLE public.weekly_room_reward_claims
  ADD COLUMN IF NOT EXISTS reward_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public.get_weekly_room_reward_progress(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_host_id uuid;
  v_is_owner boolean := false;
  v_curr_start timestamptz;
  v_curr_end timestamptz;
  v_curr_period text;
  v_curr_deadline timestamptz;
  v_claim_start timestamptz;
  v_claim_end timestamptz;
  v_claim_period text;
  v_claim_deadline timestamptz;
  v_charm bigint := 0;
  v_claim_charm bigint := 0;
  v_remaining bigint := 0;
  v_in_claim_window boolean := false;
  v_max_claim_level int := 0;
  v_any_claimed boolean := false;
  v_levels json;
  v_rules json;
BEGIN
  IF p_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid room');
  END IF;

  SELECT r.host_id INTO v_host_id
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  v_is_owner := (v_user_id IS NOT NULL AND v_user_id = v_host_id);

  SELECT w.week_start, w.week_end, w.period_key, w.claim_deadline
  INTO v_curr_start, v_curr_end, v_curr_period, v_curr_deadline
  FROM public.weekly_room_reward_week_bounds(now()) w;

  SELECT w.week_start, w.week_end, w.period_key, w.claim_deadline
  INTO v_claim_start, v_claim_end, v_claim_period, v_claim_deadline
  FROM public.weekly_room_reward_week_bounds(v_curr_start - interval '1 second') w;

  v_remaining := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_curr_end - now())))::bigint);
  v_in_claim_window := now() >= v_claim_end AND now() < v_claim_deadline;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_charm
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= v_curr_start
    AND gl.created_at < v_curr_end;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_claim_charm
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= v_claim_start
    AND gl.created_at < v_claim_end;

  SELECT COALESCE(MAX(l.level), 0)
  INTO v_max_claim_level
  FROM public.weekly_room_reward_levels l
  WHERE l.is_active = true
    AND l.required_points <= v_claim_charm;

  SELECT EXISTS (
    SELECT 1
    FROM public.weekly_room_reward_claims c
    WHERE c.room_id = p_room_id
      AND c.period_key = v_claim_period
  ) INTO v_any_claimed;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level), '[]'::json)
  INTO v_levels
  FROM (
    SELECT
      l.level,
      l.required_points,
      l.coin_reward,
      l.reward_type,
      l.shop_item_id,
      l.duration_days,
      l.title,
      l.image_url,
      l.is_active,
      (v_charm >= l.required_points) AS target_reached,
      EXISTS (
        SELECT 1
        FROM public.weekly_room_reward_claims c
        WHERE c.room_id = p_room_id
          AND c.level = l.level
          AND c.period_key = v_claim_period
      ) AS claimed,
      (
        v_is_owner
        AND l.is_active
        AND v_in_claim_window
        AND NOT v_any_claimed
        AND v_max_claim_level > 0
        AND l.level = v_max_claim_level
      ) AS can_claim,
      (
        NOT v_any_claimed
        AND v_max_claim_level > 0
        AND l.level = v_max_claim_level
        AND v_claim_charm >= l.required_points
        AND now() >= v_claim_deadline
      ) AS expired
    FROM public.weekly_room_reward_levels l
    ORDER BY l.sort_order, l.level
  ) t;

  SELECT COALESCE(r.rules, '[]'::jsonb)::json
  INTO v_rules
  FROM public.weekly_room_reward_rules r
  WHERE r.id = 1;

  RETURN json_build_object(
    'success', true,
    'charm', v_charm,
    'claim_charm', v_claim_charm,
    'is_owner', v_is_owner,
    'period_key', v_curr_period,
    'claim_period_key', v_claim_period,
    'max_claim_level', v_max_claim_level,
    'week_start', v_curr_start,
    'week_end', v_curr_end,
    'claim_deadline', v_claim_deadline,
    'in_claim_window', v_in_claim_window,
    'remaining_seconds', v_remaining,
    'levels', COALESCE(v_levels, '[]'::json),
    'rules', COALESCE(v_rules, '[]'::json)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.claim_weekly_room_reward(
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
  v_host_id uuid;
  v_curr_start timestamptz;
  v_claim_start timestamptz;
  v_claim_end timestamptz;
  v_claim_period text;
  v_claim_deadline timestamptz;
  v_claim_charm bigint := 0;
  v_required bigint;
  v_coin_reward bigint;
  v_reward_type text;
  v_shop_item_id uuid;
  v_duration integer;
  v_title text;
  v_image_url text;
  v_max_claim_level int := 0;
  v_claim_id uuid;
  v_expires timestamptz;
  v_snapshot jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid params');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.weekly_room_reward_levels l
    WHERE l.level = p_level
      AND l.is_active = true
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  SELECT r.host_id INTO v_host_id
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  IF v_user_id <> v_host_id THEN
    RETURN json_build_object('success', false, 'message', 'Only room owner can claim');
  END IF;

  SELECT w.week_start
  INTO v_curr_start
  FROM public.weekly_room_reward_week_bounds(now()) w;

  SELECT w.week_start, w.week_end, w.period_key, w.claim_deadline
  INTO v_claim_start, v_claim_end, v_claim_period, v_claim_deadline
  FROM public.weekly_room_reward_week_bounds(v_curr_start - interval '1 second') w;

  IF now() < v_claim_end THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Rewards unlock after this week ends'
    );
  END IF;

  IF now() >= v_claim_deadline THEN
    RETURN json_build_object('success', false, 'message', 'Claim window expired');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.weekly_room_reward_claims c
    WHERE c.room_id = p_room_id
      AND c.period_key = v_claim_period
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Already claimed for this week'
    );
  END IF;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_claim_charm
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= v_claim_start
    AND gl.created_at < v_claim_end;

  SELECT COALESCE(MAX(l.level), 0)
  INTO v_max_claim_level
  FROM public.weekly_room_reward_levels l
  WHERE l.is_active = true
    AND l.required_points <= v_claim_charm;

  IF v_max_claim_level = 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Room target not reached for last week',
      'charm', v_claim_charm
    );
  END IF;

  IF p_level <> v_max_claim_level THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Only the highest unlocked level can be claimed',
      'max_level', v_max_claim_level,
      'requested_level', p_level
    );
  END IF;

  SELECT
    l.required_points,
    l.coin_reward,
    COALESCE(l.reward_type, 'coins'),
    l.shop_item_id,
    l.duration_days,
    COALESCE(NULLIF(trim(l.title), ''), ''),
    COALESCE(l.image_url, '')
  INTO
    v_required,
    v_coin_reward,
    v_reward_type,
    v_shop_item_id,
    v_duration,
    v_title,
    v_image_url
  FROM public.weekly_room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  v_snapshot := jsonb_build_object(
    'level', p_level,
    'reward_type', v_reward_type,
    'coin_amount', COALESCE(v_coin_reward, 0),
    'shop_item_id', v_shop_item_id,
    'title', v_title,
    'image_url', v_image_url,
    'period_key', v_claim_period
  );

  IF v_reward_type = 'shop_item' THEN
    IF v_shop_item_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Shop item not configured');
    END IF;

    SELECT COALESCE(v_duration, si.duration_days, 0),
           CASE WHEN v_title = '' THEN COALESCE(si.name, 'Reward') ELSE v_title END,
           CASE WHEN v_image_url = '' THEN COALESCE(si.image_url, '') ELSE v_image_url END
    INTO v_duration, v_title, v_image_url
    FROM public.shop_items si
    WHERE si.id = v_shop_item_id
      AND si.is_active = true;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Shop item missing');
    END IF;

    v_expires := CASE
      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
      ELSE '9999-12-31'::timestamptz
    END;

    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
    VALUES (v_user_id, v_shop_item_id, 'weekly_room_reward', v_expires)
    ON CONFLICT (user_id, item_id) DO UPDATE
      SET expires_at = GREATEST(public.user_inventory.expires_at, EXCLUDED.expires_at),
          source = COALESCE(public.user_inventory.source, EXCLUDED.source);

    v_snapshot := v_snapshot || jsonb_build_object(
      'title', v_title,
      'image_url', v_image_url,
      'duration_days', v_duration,
      'expires_at', v_expires
    );
    v_coin_reward := 0;
  ELSIF v_coin_reward > 0 THEN
    UPDATE public.users
    SET coins = coins + v_coin_reward
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id,
      v_coin_reward,
      'coin',
      'weekly_room_reward',
      p_room_id
    );
  ELSE
    RETURN json_build_object('success', false, 'message', 'No reward configured');
  END IF;

  INSERT INTO public.weekly_room_reward_claims (
    room_id, owner_id, level, period_key, coin_amount, reward_snapshot
  ) VALUES (
    p_room_id, v_user_id, p_level, v_claim_period, COALESCE(v_coin_reward, 0), v_snapshot
  )
  RETURNING id INTO v_claim_id;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'level', p_level,
    'coin_amount', COALESCE(v_coin_reward, 0),
    'reward', v_snapshot,
    'period_key', v_claim_period
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  WHEN others THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_weekly_room_reward_progress(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_weekly_room_reward(uuid, integer) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
