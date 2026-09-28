-- Lucky bags auto-hide after 2 minutes if unclaimed.
-- Cron expires due bags and refunds leftover coins to the sender.

CREATE OR REPLACE FUNCTION public.expire_lucky_bag(p_bag_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bag public.lucky_bags%ROWTYPE;
BEGIN
  SELECT * INTO v_bag
  FROM public.lucky_bags
  WHERE id = p_bag_id
  FOR UPDATE;

  IF NOT FOUND OR v_bag.status <> 'active' THEN
    RETURN false;
  END IF;

  IF COALESCE(v_bag.remaining_coins, 0) > 0 THEN
    UPDATE public.users
    SET coins = coins + v_bag.remaining_coins
    WHERE id = v_bag.sender_id;
  END IF;

  UPDATE public.lucky_bags
  SET
    status = 'expired',
    remaining_coins = 0
  WHERE id = p_bag_id
    AND status = 'active';

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.expire_due_lucky_bags()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_expired int := 0;
BEGIN
  FOR v_id IN
    SELECT id
    FROM public.lucky_bags
    WHERE status = 'active'
      AND expires_at <= now()
  LOOP
    IF public.expire_lucky_bag(v_id) THEN
      v_expired := v_expired + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('expired', v_expired);
END;
$$;

REVOKE ALL ON FUNCTION public.expire_lucky_bag(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.expire_due_lucky_bags() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expire_lucky_bag(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.expire_due_lucky_bags() TO service_role;

CREATE OR REPLACE FUNCTION public.create_lucky_bag(
  p_room_id uuid,
  p_scope text,
  p_tier_id uuid,
  p_recipient_count integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_tier public.lucky_bag_tiers%ROWTYPE;
  v_sender_coins bigint;
  v_splits integer[];
  v_bag_id uuid;
  v_sender_name text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_scope NOT IN ('room', 'world') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid scope');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  SELECT * INTO v_tier
  FROM public.lucky_bag_tiers
  WHERE id = p_tier_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Tier not found');
  END IF;

  IF NOT (p_recipient_count = ANY (v_tier.recipient_options)) THEN
    RETURN json_build_object('success', false, 'message', 'Invalid recipient count');
  END IF;

  SELECT coins INTO v_sender_coins
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF COALESCE(v_sender_coins, 0) < v_tier.total_coins THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  v_splits := public.generate_lucky_bag_splits(v_tier.total_coins, p_recipient_count);

  UPDATE public.users
  SET coins = coins - v_tier.total_coins
  WHERE id = v_user_id;

  INSERT INTO public.lucky_bags (
    room_id,
    sender_id,
    scope,
    tier_id,
    total_coins,
    recipient_count,
    remaining_coins,
    coin_splits,
    expires_at
  )
  VALUES (
    p_room_id,
    v_user_id,
    p_scope,
    p_tier_id,
    v_tier.total_coins,
    p_recipient_count,
    v_tier.total_coins,
    v_splits,
    now() + interval '2 minutes'
  )
  RETURNING id INTO v_bag_id;

  SELECT username INTO v_sender_name FROM public.users WHERE id = v_user_id;

  RETURN json_build_object(
    'success', true,
    'bag_id', v_bag_id,
    'scope', p_scope,
    'total_coins', v_tier.total_coins,
    'recipient_count', p_recipient_count,
    'sender_name', COALESCE(v_sender_name, 'User')
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.claim_lucky_bag(p_bag_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_bag public.lucky_bags%ROWTYPE;
  v_claim_amount integer;
  v_claim_index integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_bag
  FROM public.lucky_bags
  WHERE id = p_bag_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Bag not found');
  END IF;

  IF v_bag.status <> 'active' THEN
    RETURN json_build_object('success', false, 'message', 'Bag is no longer active');
  END IF;

  IF v_bag.expires_at <= now() THEN
    PERFORM public.expire_lucky_bag(p_bag_id);
    RETURN json_build_object('success', false, 'message', 'Bag expired');
  END IF;

  IF v_bag.claimed_count >= v_bag.recipient_count THEN
    UPDATE public.lucky_bags SET status = 'finished' WHERE id = p_bag_id;
    RETURN json_build_object('success', false, 'message', 'Bag fully claimed');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.lucky_bag_claims
    WHERE bag_id = p_bag_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  END IF;

  IF v_bag.sender_id = v_user_id THEN
    RETURN json_build_object('success', false, 'message', 'Sender cannot claim own bag');
  END IF;

  v_claim_index := v_bag.claimed_count + 1;
  v_claim_amount := v_bag.coin_splits[v_claim_index];

  INSERT INTO public.lucky_bag_claims (bag_id, user_id, coins)
  VALUES (p_bag_id, v_user_id, v_claim_amount);

  UPDATE public.users
  SET coins = coins + v_claim_amount
  WHERE id = v_user_id;

  UPDATE public.lucky_bags
  SET
    claimed_count = claimed_count + 1,
    remaining_coins = remaining_coins - v_claim_amount,
    status = CASE
      WHEN claimed_count + 1 >= recipient_count THEN 'finished'
      ELSE status
    END
  WHERE id = p_bag_id;

  RETURN json_build_object(
    'success', true,
    'coins', v_claim_amount,
    'remaining_slots', v_bag.recipient_count - v_bag.claimed_count - 1
  );
END;
$function$;

-- Existing live bags follow the 2-minute rule from created_at.
UPDATE public.lucky_bags
SET expires_at = created_at + interval '2 minutes'
WHERE status = 'active'
  AND expires_at > created_at + interval '2 minutes';

SELECT public.expire_due_lucky_bags();

DO $outer$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname = 'expire-lucky-bags';
EXCEPTION
  WHEN others THEN NULL;
END;
$outer$;

DO $outer$
BEGIN
  PERFORM cron.schedule(
    'expire-lucky-bags',
    '* * * * *',
    $cron$SELECT public.expire_due_lucky_bags();$cron$
  );
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END;
$outer$;
