-- Prize-level "Coming soon" for Lucky Offer / Rupee Game.
ALTER TABLE public.rupee_game_prizes
  ADD COLUMN IF NOT EXISTS coming_soon boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.enter_rupee_game(p_prize_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_prize public.rupee_game_prizes%ROWTYPE;
  v_campaign public.rupee_game_campaigns%ROWTYPE;
  v_user_coins bigint;
  v_campaign_entries integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_prize
  FROM public.rupee_game_prizes
  WHERE id = p_prize_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Prize not found');
  END IF;

  IF COALESCE(v_prize.coming_soon, false) THEN
    RETURN json_build_object('success', false, 'message', 'Coming soon');
  END IF;

  IF v_prize.draw_status <> 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Prize draw already completed');
  END IF;

  SELECT * INTO v_campaign
  FROM public.rupee_game_campaigns
  WHERE id = v_prize.campaign_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Campaign not found');
  END IF;

  IF v_campaign.status <> 'active' OR NOT v_campaign.is_active THEN
    RETURN json_build_object('success', false, 'message', 'Campaign is not active');
  END IF;

  IF now() < v_campaign.starts_at OR now() > v_campaign.ends_at THEN
    RETURN json_build_object('success', false, 'message', 'Campaign is outside its date window');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.rupee_game_entries
    WHERE prize_id = p_prize_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already participated in this prize');
  END IF;

  SELECT COUNT(*)::integer INTO v_campaign_entries
  FROM public.rupee_game_entries
  WHERE campaign_id = v_campaign.id AND user_id = v_user_id;

  IF v_campaign_entries >= v_campaign.max_entries_per_user THEN
    RETURN json_build_object('success', false, 'message', 'Campaign entry limit reached');
  END IF;

  SELECT coins INTO v_user_coins
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF COALESCE(v_user_coins, 0) < v_campaign.entry_price_coins THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  UPDATE public.users
  SET coins = coins - v_campaign.entry_price_coins
  WHERE id = v_user_id;

  INSERT INTO public.rupee_game_entries (
    campaign_id, prize_id, user_id, coins_paid
  )
  VALUES (
    v_campaign.id, p_prize_id, v_user_id, v_campaign.entry_price_coins
  );

  UPDATE public.rupee_game_prizes
  SET participant_count = participant_count + 1,
      updated_at = now()
  WHERE id = p_prize_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  )
  VALUES (
    v_user_id,
    -v_campaign.entry_price_coins,
    'coins',
    'rupee_game_entry',
    p_prize_id
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Participation confirmed',
    'coins_paid', v_campaign.entry_price_coins,
    'participant_count', v_prize.participant_count + 1
  );
END;
$function$;
