-- Allow reseller to send coins to own ID (stock → personal coins)
-- and allow wallet withdraw / cash-exchange-other targeting own ID.

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
  v_is_self boolean := false;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Amount must be greater than zero');
  END IF;

  IF p_sender_id IS DISTINCT FROM auth.uid() AND auth.role() <> 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  v_is_self := (p_sender_id = p_receiver_id);

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

  IF NOT v_is_self AND NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_receiver_id) THEN
    RETURN json_build_object('success', false, 'message', 'Receiver not found');
  END IF;

  IF v_is_self THEN
    -- Convert reseller stock into own spendable coins
    UPDATE public.users
    SET
      reseller_coins = reseller_coins - p_amount,
      coins = COALESCE(coins, 0) + p_amount,
      updated_at = now()
    WHERE id = p_sender_id;

    INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
    VALUES (
      p_sender_id,
      p_amount,
      'transfer_out',
      'coin',
      p_sender_id,
      'Reseller coins converted to own wallet'
    );

    INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
    VALUES (
      p_sender_id,
      p_amount,
      'transfer_in',
      'coin',
      p_sender_id,
      'Coins received from own reseller stock'
    );

    INSERT INTO public.system_notifications (
      user_id, title, content, type, icon_type, metadata
    ) VALUES (
      p_sender_id,
      'Coins Received',
      format(
        'You converted %s reseller coins to your wallet.',
        to_char(p_amount, 'FM999,999,999,999')
      ),
      'reseller_transfer',
      'coins',
      jsonb_build_object(
        'seller_id', p_sender_id::text,
        'seller_name', v_seller_name,
        'seller_short_id', COALESCE(v_seller_short_id, ''),
        'amount', p_amount::text,
        'currency', 'coin',
        'self_transfer', 'true'
      )
    );

    RETURN json_build_object('success', true, 'message', 'Transferred to your own wallet');
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

-- Cash exchange to other: allow own ID (same effect as self exchange path)
CREATE OR REPLACE FUNCTION public.exchange_cash_to_other(
  p_target_user_id uuid,
  p_amount_usd numeric
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_cash numeric(12, 2);
  v_target_username text;
  v_cfg public.cash_exchange_configs%ROWTYPE;
  v_base bigint;
  v_bonus bigint;
  v_total bigint;
  v_is_self boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_target_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid target user');
  END IF;

  v_is_self := (p_target_user_id = v_uid);

  IF p_amount_usd IS NULL OR p_amount_usd <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid amount');
  END IF;

  SELECT * INTO v_cfg
  FROM public.cash_exchange_configs
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_cfg.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Exchange config missing');
  END IF;

  SELECT cash_balance INTO v_cash FROM public.users WHERE id = v_uid FOR UPDATE;
  IF COALESCE(v_cash, 0) < p_amount_usd THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient cash balance');
  END IF;

  IF v_is_self THEN
    v_target_username := (SELECT username FROM public.users WHERE id = v_uid);
  ELSE
    SELECT username INTO v_target_username FROM public.users WHERE id = p_target_user_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Target user not found');
    END IF;
  END IF;

  v_base := floor(p_amount_usd * v_cfg.coins_per_dollar)::bigint;
  v_bonus := floor(v_base * COALESCE(v_cfg.bonus_percent, 0) / 100.0)::bigint;
  v_total := v_base + v_bonus;

  IF v_is_self THEN
    UPDATE public.users
    SET
      cash_balance = cash_balance - p_amount_usd,
      coins = COALESCE(coins, 0) + v_total,
      updated_at = now()
    WHERE id = v_uid;

    INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
    VALUES (
      v_uid,
      v_total,
      'cash_exchange_self',
      'coin',
      v_uid,
      format('Cash $%s → own coins', p_amount_usd)
    );
  ELSE
    UPDATE public.users
    SET cash_balance = cash_balance - p_amount_usd
    WHERE id = v_uid;

    UPDATE public.users
    SET coins = COALESCE(coins, 0) + v_total
    WHERE id = p_target_user_id;

    INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
    VALUES (
      v_uid,
      v_total,
      'cash_exchange_other_out',
      'coin',
      p_target_user_id,
      format('Cash $%s → coins for %s', p_amount_usd, COALESCE(v_target_username, p_target_user_id::text))
    );

    INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
    VALUES (
      p_target_user_id,
      v_total,
      'cash_exchange_other_in',
      'coin',
      v_uid,
      'Coins received from cash exchange'
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'Exchange successful',
    'coins', v_total,
    'base_coins', v_base,
    'bonus_coins', v_bonus
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.exchange_cash_to_other(uuid, numeric) TO authenticated;

-- Withdrawal: allow targeting own ID when user is reseller / agency owner
CREATE OR REPLACE FUNCTION public.request_cash_withdrawal(
  p_amount numeric,
  p_target_type text,
  p_target_user_id uuid,
  p_payment_method_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_cash numeric(12, 2);
  v_cfg public.withdrawal_configs%ROWTYPE;
  v_day integer;
  v_fee numeric(12, 2);
  v_net numeric(12, 2);
  v_pm public.user_payment_methods%ROWTYPE;
  v_target_ok boolean := false;
  v_withdrawal_id uuid;
  v_pm_json jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid amount');
  END IF;

  IF p_target_type IS NULL OR p_target_type NOT IN ('reseller', 'agent') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid target type');
  END IF;

  IF p_target_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid target user');
  END IF;

  SELECT * INTO v_cfg
  FROM public.withdrawal_configs
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_cfg.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Withdrawal config missing');
  END IF;

  v_day := EXTRACT(
    DAY FROM ((now() AT TIME ZONE 'UTC') + make_interval(hours => v_cfg.timezone_offset_hours))
  )::integer;

  IF NOT (v_day = ANY (v_cfg.allowed_days)) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Withdrawals are only allowed on the 1st–5th and 16th–20th of each month (UTC+3)'
    );
  END IF;

  IF p_amount < COALESCE(v_cfg.min_amount, 1) THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Minimum withdrawal amount is $%s', v_cfg.min_amount)
    );
  END IF;

  SELECT * INTO v_pm
  FROM public.user_payment_methods
  WHERE id = p_payment_method_id AND user_id = v_uid;

  IF v_pm.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Please select a payment method');
  END IF;

  v_pm_json := jsonb_build_object(
    'id', v_pm.id,
    'method', v_pm.method,
    'name', v_pm.name,
    'address', v_pm.address
  );

  IF p_target_type = 'reseller' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = p_target_user_id AND is_reseller IS TRUE
    ) INTO v_target_ok;
    IF NOT v_target_ok THEN
      RETURN json_build_object('success', false, 'message', 'Target is not an authorized coin reseller');
    END IF;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM public.agencies
      WHERE owner_id = p_target_user_id AND COALESCE(is_active, true) IS TRUE
    ) INTO v_target_ok;
    IF NOT v_target_ok THEN
      RETURN json_build_object('success', false, 'message', 'Target is not an authorized agent (agency owner)');
    END IF;
  END IF;

  SELECT cash_balance INTO v_cash FROM public.users WHERE id = v_uid FOR UPDATE;
  IF COALESCE(v_cash, 0) < p_amount THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient cash balance');
  END IF;

  v_fee := ROUND(p_amount * COALESCE(v_cfg.fee_percent, 0) / 100.0, 2);
  v_net := p_amount - v_fee;

  UPDATE public.users
  SET cash_balance = cash_balance - p_amount
  WHERE id = v_uid;

  INSERT INTO public.wallet_withdrawals (
    user_id, amount, fee, net_amount, target_type, target_user_id, payment_method, status
  ) VALUES (
    v_uid, p_amount, v_fee, v_net, p_target_type, p_target_user_id, v_pm_json, 'pending'
  )
  RETURNING id INTO v_withdrawal_id;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    v_uid,
    GREATEST(1, ROUND(p_amount)::bigint),
    'withdrawal_hold',
    'cash',
    v_withdrawal_id,
    format('Withdrawal hold $%s (fee $%s, net $%s) via %s', p_amount, v_fee, v_net, p_target_type)
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Withdrawal request submitted',
    'withdrawal_id', v_withdrawal_id,
    'amount', p_amount,
    'fee', v_fee,
    'net_amount', v_net
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.request_cash_withdrawal(numeric, text, uuid, uuid) TO authenticated;
