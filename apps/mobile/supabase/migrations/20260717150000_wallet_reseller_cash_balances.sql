-- Wallet + Reseller: separate reseller stock + cash balance exchanges

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS reseller_coins bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cash_balance numeric(12, 2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.cash_exchange_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coins_per_dollar bigint NOT NULL DEFAULT 68000,
  bonus_percent numeric(6, 2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.cash_exchange_configs (coins_per_dollar, bonus_percent, is_active)
SELECT 68000, 32, true
WHERE NOT EXISTS (
  SELECT 1 FROM public.cash_exchange_configs WHERE is_active = true
);

ALTER TABLE public.cash_exchange_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read cash exchange configs" ON public.cash_exchange_configs;
CREATE POLICY "Authenticated read cash exchange configs"
  ON public.cash_exchange_configs FOR SELECT TO authenticated
  USING (true);

-- Debit reseller_coins (stock), credit receiver personal coins.
-- Keep transfer_out / transfer_in + reference_id so get_reseller_history still works.
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

  SELECT reseller_coins, is_reseller
  INTO v_sender_stock, v_sender_is_reseller
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
  VALUES (p_sender_id, p_amount, 'transfer_out', 'coin', p_receiver_id, 'Reseller coins transferred to client');

  INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, reference_id, description)
  VALUES (p_receiver_id, p_amount, 'transfer_in', 'coin', p_sender_id, 'Coins received from reseller');

  RETURN json_build_object('success', true, 'message', 'Transfer completed successfully');
END;
$function$;

CREATE OR REPLACE FUNCTION public.exchange_cash_to_self(p_amount_usd numeric)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_cash numeric(12, 2);
  v_cfg public.cash_exchange_configs%ROWTYPE;
  v_base bigint;
  v_bonus bigint;
  v_total bigint;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

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

  v_base := floor(p_amount_usd * v_cfg.coins_per_dollar)::bigint;
  v_bonus := floor(v_base * COALESCE(v_cfg.bonus_percent, 0) / 100.0)::bigint;
  v_total := v_base + v_bonus;

  UPDATE public.users
  SET
    cash_balance = cash_balance - p_amount_usd,
    coins = COALESCE(coins, 0) + v_total
  WHERE id = v_uid;

  INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, description)
  VALUES (
    v_uid,
    v_total,
    'cash_exchange_self',
    'coin',
    format('Cash $%s → %s coins (+%s%% bonus)', p_amount_usd, v_total, v_cfg.bonus_percent)
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Exchange successful',
    'coins', v_total,
    'base_coins', v_base,
    'bonus_coins', v_bonus
  );
END;
$function$;

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
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_target_user_id IS NULL OR p_target_user_id = v_uid THEN
    RETURN json_build_object('success', false, 'message', 'Invalid target user');
  END IF;

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

  SELECT username INTO v_target_username FROM public.users WHERE id = p_target_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Target user not found');
  END IF;

  v_base := floor(p_amount_usd * v_cfg.coins_per_dollar)::bigint;
  v_bonus := floor(v_base * COALESCE(v_cfg.bonus_percent, 0) / 100.0)::bigint;
  v_total := v_base + v_bonus;

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

  RETURN json_build_object(
    'success', true,
    'message', 'Exchange successful',
    'coins', v_total,
    'base_coins', v_base,
    'bonus_coins', v_bonus
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.transfer_coins_reseller(uuid, uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_coins_reseller(uuid, uuid, bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.exchange_cash_to_self(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exchange_cash_to_other(uuid, numeric) TO authenticated;

NOTIFY pgrst, 'reload schema';
