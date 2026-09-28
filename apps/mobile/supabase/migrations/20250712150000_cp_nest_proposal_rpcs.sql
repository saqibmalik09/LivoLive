-- CP Nest: send / respond / breakup via SECURITY DEFINER RPCs
-- Root cause: cp_proposals had only SELECT RLS; couples had only SELECT.
-- Client inserts/updates failed with "new row violates row-level security".

CREATE OR REPLACE FUNCTION public.send_cp_proposal(
  p_item_id uuid,
  p_receiver_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_sender_id uuid := auth.uid();
  v_item public.cp_nest_items%ROWTYPE;
  v_coins bigint;
  v_proposal_id uuid;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_receiver_id IS NULL OR p_receiver_id = v_sender_id THEN
    RETURN json_build_object('success', false, 'message', 'Invalid receiver');
  END IF;

  SELECT * INTO v_item
  FROM public.cp_nest_items
  WHERE id = p_item_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'CP item not found');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.couples
    WHERE user1_id = v_sender_id OR user2_id = v_sender_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'You are already in a couple. Break up first.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.couples
    WHERE user1_id = p_receiver_id OR user2_id = p_receiver_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'The user is already in a couple.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.cp_proposals
    WHERE sender_id = v_sender_id AND status = 'pending' AND expires_at > now()
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You already have a pending proposal. Wait for it to expire or be rejected.'
    );
  END IF;

  SELECT coins INTO v_coins
  FROM public.users
  WHERE id = v_sender_id
  FOR UPDATE;

  IF COALESCE(v_coins, 0) < v_item.price THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins. Please recharge first.');
  END IF;

  UPDATE public.users
  SET coins = coins - v_item.price
  WHERE id = v_sender_id;

  INSERT INTO public.cp_proposals (
    sender_id, receiver_id, item_id, status, expires_at
  )
  VALUES (
    v_sender_id, p_receiver_id, p_item_id, 'pending', now() + interval '24 hours'
  )
  RETURNING id INTO v_proposal_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  )
  VALUES (
    v_sender_id, -v_item.price, 'coin', 'purchase', v_proposal_id
  );

  RETURN json_build_object(
    'success', true,
    'proposal_id', v_proposal_id,
    'price', v_item.price
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.respond_to_cp_proposal(
  p_proposal_id uuid,
  p_accept boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_proposal public.cp_proposals%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_proposal
  FROM public.cp_proposals
  WHERE id = p_proposal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Proposal not found');
  END IF;

  IF v_proposal.receiver_id <> v_user_id THEN
    RETURN json_build_object('success', false, 'message', 'Not your proposal to respond to');
  END IF;

  IF v_proposal.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Proposal is no longer pending');
  END IF;

  IF v_proposal.expires_at IS NOT NULL AND v_proposal.expires_at <= now() THEN
    UPDATE public.cp_proposals SET status = 'expired' WHERE id = p_proposal_id;
    RETURN json_build_object('success', false, 'message', 'Proposal has expired');
  END IF;

  IF NOT COALESCE(p_accept, false) THEN
    UPDATE public.cp_proposals SET status = 'rejected' WHERE id = p_proposal_id;
    RETURN json_build_object('success', true, 'status', 'rejected');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.couples
    WHERE user1_id IN (v_proposal.sender_id, v_proposal.receiver_id)
       OR user2_id IN (v_proposal.sender_id, v_proposal.receiver_id)
  ) THEN
    RETURN json_build_object('success', false, 'message', 'One of the partners is already in a couple.');
  END IF;

  INSERT INTO public.couples (user1_id, user2_id)
  VALUES (v_proposal.sender_id, v_proposal.receiver_id);

  UPDATE public.cp_proposals SET status = 'accepted' WHERE id = p_proposal_id;

  RETURN json_build_object('success', true, 'status', 'accepted');
END;
$function$;

CREATE OR REPLACE FUNCTION public.breakup_couple()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_couple public.couples%ROWTYPE;
  v_gender text;
  v_coins bigint;
  v_penalty bigint := 5000;
  v_cfg jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_couple
  FROM public.couples
  WHERE user1_id = v_user_id OR user2_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'You are not in a couple.');
  END IF;

  SELECT lower(COALESCE(gender::text, '')), coins
  INTO v_gender, v_coins
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF v_gender IN ('female', '2') THEN
    SELECT value INTO v_cfg
    FROM public.cp_configs
    WHERE key = 'breakup_penalty'
    LIMIT 1;

    IF v_cfg IS NOT NULL THEN
      v_penalty := COALESCE(
        (v_cfg->>'female_coins')::bigint,
        (v_cfg->>'female_beans')::bigint,
        v_penalty
      );
    END IF;

    IF COALESCE(v_coins, 0) < v_penalty THEN
      RETURN json_build_object(
        'success', false,
        'message', format('You need at least %s coins to break up.', v_penalty)
      );
    END IF;

    UPDATE public.users
    SET coins = coins - v_penalty
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    )
    VALUES (
      v_user_id, -v_penalty, 'coin', 'purchase', v_couple.id
    );
  END IF;

  DELETE FROM public.couples WHERE id = v_couple.id;

  RETURN json_build_object('success', true);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.send_cp_proposal(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_cp_proposal(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.breakup_couple() TO authenticated;
