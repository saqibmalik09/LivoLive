-- Weekly room rewards: claim only after week ends (previous period), not during active week.

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

  -- Current active week (display progress)
  SELECT w.week_start, w.week_end, w.period_key, w.claim_deadline
  INTO v_curr_start, v_curr_end, v_curr_period, v_curr_deadline
  FROM public.weekly_room_reward_week_bounds(now()) w;

  -- Most recently finished week (only this period is claimable)
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

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level), '[]'::json)
  INTO v_levels
  FROM (
    SELECT
      l.level,
      l.required_points,
      l.coin_reward,
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
        AND v_claim_charm >= l.required_points
        AND NOT EXISTS (
          SELECT 1
          FROM public.weekly_room_reward_claims c
          WHERE c.room_id = p_room_id
            AND c.level = l.level
            AND c.period_key = v_claim_period
        )
      ) AS can_claim,
      (
        NOT EXISTS (
          SELECT 1
          FROM public.weekly_room_reward_claims c
          WHERE c.room_id = p_room_id
            AND c.level = l.level
            AND c.period_key = v_claim_period
        )
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
  v_claim_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 OR p_level > 5 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid params');
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

  -- Must wait until the week ends; only claim the immediately previous period
  IF now() < v_claim_end THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Rewards unlock after this week ends'
    );
  END IF;

  IF now() >= v_claim_deadline THEN
    RETURN json_build_object('success', false, 'message', 'Claim window expired');
  END IF;

  SELECT l.required_points, l.coin_reward
  INTO v_required, v_coin_reward
  FROM public.weekly_room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.weekly_room_reward_claims c
    WHERE c.room_id = p_room_id
      AND c.level = p_level
      AND c.period_key = v_claim_period
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  END IF;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_claim_charm
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= v_claim_start
    AND gl.created_at < v_claim_end;

  IF v_claim_charm < v_required THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Room target not reached for last week',
      'charm', v_claim_charm,
      'required', v_required
    );
  END IF;

  IF v_coin_reward > 0 THEN
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
  END IF;

  INSERT INTO public.weekly_room_reward_claims (
    room_id, owner_id, level, period_key, coin_amount
  ) VALUES (
    p_room_id, v_user_id, p_level, v_claim_period, v_coin_reward
  )
  RETURNING id INTO v_claim_id;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'level', p_level,
    'coin_amount', v_coin_reward,
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
