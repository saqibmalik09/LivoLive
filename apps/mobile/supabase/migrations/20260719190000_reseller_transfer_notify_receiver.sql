-- Notify receiver when a coin seller transfers coins (in-app + push via existing trigger).

CREATE OR REPLACE FUNCTION public.transfer_coins_reseller(
  p_sender_id uuid,
  p_receiver_id uuid,
  p_amount bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_sender_stock bigint;
  v_sender_is_reseller boolean;
  v_seller_name text;
  v_seller_short_id text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Amount must be greater than zero');
  END IF;

  IF p_sender_id IS DISTINCT FROM auth.uid() AND auth.role() <> 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_sender_id = p_receiver_id THEN
    RETURN json_build_object('success', false, 'message', 'Cannot transfer to yourself');
  END IF;

  SELECT reseller_coins, is_reseller, COALESCE(username, 'Seller'), short_id::text
  INTO v_sender_stock, v_sender_is_reseller, v_seller_name, v_seller_short_id
  FROM public.users
  WHERE id = p_sender_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Sender not found');
  END IF;

  IF v_sender_is_reseller IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'Sender is not an authorized reseller');
  END IF;

  IF COALESCE(v_sender_stock, 0) < p_amount THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient reseller coins');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_receiver_id) THEN
    RETURN json_build_object('success', false, 'message', 'Receiver not found');
  END IF;

  UPDATE public.users
  SET reseller_coins = reseller_coins - p_amount
  WHERE id = p_sender_id;

  UPDATE public.users
  SET coins = COALESCE(coins, 0) + p_amount
  WHERE id = p_receiver_id;

  INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
  VALUES (
    p_sender_id,
    p_amount,
    'transfer_out',
    'coin',
    p_receiver_id,
    'Reseller coins transferred to client'
  );

  INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
  VALUES (
    p_receiver_id,
    p_amount,
    'transfer_in',
    'coin',
    p_sender_id,
    format('Coins received from seller %s', v_seller_name)
  );

  INSERT INTO public.system_notifications (
    user_id, title, content, type, icon_type, metadata
  ) VALUES (
    p_receiver_id,
    'Coins Received',
    CASE
      WHEN v_seller_short_id IS NOT NULL AND v_seller_short_id <> ''
        THEN format(
          'Seller %s (UID %s) sent you %s coins.',
          v_seller_name,
          v_seller_short_id,
          to_char(p_amount, 'FM999,999,999,999')
        )
      ELSE format(
        'Seller %s sent you %s coins.',
        v_seller_name,
        to_char(p_amount, 'FM999,999,999,999')
      )
    END,
    'reseller_transfer',
    'coins',
    -- FCM data payloads require string values only
    jsonb_build_object(
      'seller_id', p_sender_id::text,
      'seller_name', v_seller_name,
      'seller_short_id', COALESCE(v_seller_short_id, ''),
      'amount', p_amount::text,
      'currency', 'coin'
    )
  );

  RETURN json_build_object('success', true, 'message', 'Transfer completed successfully');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.transfer_coins_reseller(uuid, uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_coins_reseller(uuid, uuid, bigint) TO service_role;
