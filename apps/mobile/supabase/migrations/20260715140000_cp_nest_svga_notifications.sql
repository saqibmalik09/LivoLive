-- CP Nest: SVGA assets + in-app proposal notifications

ALTER TABLE public.cp_nest_items
  ADD COLUMN IF NOT EXISTS svga_url text;

-- Allow SVGA uploads in cp_nest_assets bucket
UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'application/octet-stream'
]::text[],
    file_size_limit = GREATEST(COALESCE(file_size_limit, 5242880), 10485760)
WHERE id = 'cp_nest_assets';

-- ---------------------------------------------------------------------------
-- send_cp_proposal: also create system notification for receiver
-- ---------------------------------------------------------------------------
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
  v_sender_name text;
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

  SELECT COALESCE(username, 'Someone') INTO v_sender_name
  FROM public.users WHERE id = v_sender_id;

  INSERT INTO public.system_notifications (
    user_id, title, content, type, icon_type, metadata
  )
  VALUES (
    p_receiver_id,
    'CP Proposal',
    format('%s sent you a CP gift "%s". Tap to accept or reject.', v_sender_name, v_item.name),
    'cp_proposal',
    'heart',
    jsonb_build_object(
      'proposal_id', v_proposal_id,
      'sender_id', v_sender_id,
      'item_id', p_item_id,
      'item_name', v_item.name
    )
  );

  RETURN json_build_object(
    'success', true,
    'proposal_id', v_proposal_id,
    'price', v_item.price
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- respond_to_cp_proposal: notify sender on accept/reject
-- ---------------------------------------------------------------------------
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
  v_receiver_name text;
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

  SELECT COALESCE(username, 'Someone') INTO v_receiver_name
  FROM public.users WHERE id = v_user_id;

  IF NOT COALESCE(p_accept, false) THEN
    UPDATE public.cp_proposals SET status = 'rejected' WHERE id = p_proposal_id;

    INSERT INTO public.system_notifications (
      user_id, title, content, type, icon_type, metadata
    )
    VALUES (
      v_proposal.sender_id,
      'CP Proposal Declined',
      format('%s declined your CP proposal.', v_receiver_name),
      'cp_proposal_rejected',
      'heart',
      jsonb_build_object('proposal_id', p_proposal_id)
    );

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

  INSERT INTO public.system_notifications (
    user_id, title, content, type, icon_type, metadata
  )
  VALUES (
    v_proposal.sender_id,
    'CP Proposal Accepted',
    format('%s accepted your CP proposal. You are now a couple!', v_receiver_name),
    'cp_proposal_accepted',
    'heart',
    jsonb_build_object('proposal_id', p_proposal_id)
  );

  RETURN json_build_object('success', true, 'status', 'accepted');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.send_cp_proposal(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_cp_proposal(uuid, boolean) TO authenticated;
