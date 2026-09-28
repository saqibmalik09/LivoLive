-- Allow more than 5 weekly room reward levels (admin can add rows).
-- Also relax claim RPC hard cap of level <= 5.

ALTER TABLE public.weekly_room_reward_levels
  DROP CONSTRAINT IF EXISTS weekly_room_reward_levels_level_check;

ALTER TABLE public.weekly_room_reward_levels
  ADD CONSTRAINT weekly_room_reward_levels_level_check
  CHECK (level >= 1 AND level <= 50);

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
  v_max_claim_level int := 0;
  v_claim_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 OR p_level > 50 THEN
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

  SELECT l.required_points, l.coin_reward
  INTO v_required, v_coin_reward
  FROM public.weekly_room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
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

GRANT EXECUTE ON FUNCTION public.claim_weekly_room_reward(uuid, integer) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
