-- ════════════════════════════════════════════════════════════════════
-- Merchant tier — merchant RPCs (in-app panel)
--
-- Called by the merchant themselves, so each one authorises against
-- auth.uid() the way transfer_coins_reseller does, and still allows
-- service_role for admin-side tooling.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Search a coin seller by ID or name ──────────────────────────────
-- Requirement 4, first half: the merchant finds the seller by ID.
CREATE OR REPLACE FUNCTION public.merchant_search_coin_sellers(
  p_query text,
  p_limit int DEFAULT 20
) RETURNS TABLE (
  id              uuid,
  username        text,
  short_id        integer,
  avatar_url      text,
  country_code    text,
  reseller_coins  bigint,
  is_banned       boolean,
  is_mine         boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_me uuid := auth.uid();
  v_q  text := btrim(COALESCE(p_query, ''));
BEGIN
  IF v_q = '' THEN RETURN; END IF;

  IF v_me IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.users mu WHERE mu.id = v_me AND mu.is_merchant
  ) THEN
    IF auth.role() IS DISTINCT FROM 'service_role' THEN RETURN; END IF;
  END IF;

  RETURN QUERY
  SELECT u.id, u.username, u.short_id, u.avatar_url, u.country_code,
         COALESCE(u.reseller_coins, 0), COALESCE(u.is_banned, false),
         COALESCE(u.merchant_id = v_me, false)
  FROM public.users u
  WHERE u.is_reseller = true
    AND (
      (v_q ~ '^\d+$' AND u.short_id = v_q::bigint)
      OR (length(v_q) >= 2 AND u.username ILIKE '%' || v_q || '%')
    )
  ORDER BY (v_q ~ '^\d+$' AND u.short_id = NULLIF(v_q, '')::bigint) DESC NULLS LAST,
           u.username
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
END;
$fn$;

-- ── Supply a coin seller ────────────────────────────────────────────
-- Requirement 4: merchant recharges any coin seller, found by ID.
-- Moves wholesale stock (merchant_coins) into seller stock
-- (reseller_coins), recording the movement for both sides.
CREATE OR REPLACE FUNCTION public.merchant_recharge_reseller(
  p_reseller_id uuid,
  p_amount      bigint,
  p_note        text DEFAULT NULL,
  p_merchant_id uuid DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_me          uuid := COALESCE(p_merchant_id, auth.uid());
  v_stock       bigint;
  v_limit       bigint;
  v_rate        bigint;
  v_commission  numeric;
  v_blocked     boolean;
  v_after       bigint;
  v_profit      bigint;
  v_seller      record;
  v_merchant_nm text;
  v_merchant_sid text;
BEGIN
  IF v_me IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not signed in');
  END IF;

  -- A merchant may only spend their own wallet.
  IF v_me IS DISTINCT FROM auth.uid() AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Amount must be greater than zero');
  END IF;

  SELECT COALESCE(u.merchant_coins, 0), COALESCE(u.is_merchant_blocked, false),
         COALESCE(u.username, 'Merchant'), u.short_id::text,
         COALESCE(mp.credit_limit, 0), COALESCE(mp.coins_per_usd, 0),
         COALESCE(mp.commission_percent, 0)
    INTO v_stock, v_blocked, v_merchant_nm, v_merchant_sid, v_limit, v_rate, v_commission
  FROM public.users u
  LEFT JOIN public.merchant_profiles mp ON mp.user_id = u.id
  WHERE u.id = v_me AND u.is_merchant
  FOR UPDATE OF u;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'You are not an authorized merchant');
  END IF;

  IF v_blocked THEN
    RETURN json_build_object('success', false, 'message', 'Your merchant account is blocked. Contact admin.');
  END IF;

  IF v_stock + v_limit < p_amount THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Insufficient balance. You hold %s coins.', to_char(v_stock, 'FM999,999,999,999'))
    );
  END IF;

  SELECT id, COALESCE(username, 'Seller') AS username, short_id, is_reseller, merchant_id
    INTO v_seller
  FROM public.users WHERE id = p_reseller_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Coin seller not found');
  END IF;

  IF v_seller.is_reseller IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'That user is not a coin seller');
  END IF;

  IF v_seller.id = v_me THEN
    RETURN json_build_object('success', false, 'message', 'Cannot recharge your own account');
  END IF;

  v_profit := floor(p_amount::numeric * v_commission / 100)::bigint;

  UPDATE public.users
     SET merchant_coins = COALESCE(merchant_coins, 0) - p_amount, updated_at = now()
   WHERE id = v_me
  RETURNING merchant_coins INTO v_after;

  UPDATE public.users
     SET reseller_coins = COALESCE(reseller_coins, 0) + p_amount,
         -- claim only unassigned sellers; never reassign another merchant's
         merchant_id    = COALESCE(merchant_id, v_me),
         updated_at     = now()
   WHERE id = p_reseller_id;

  -- Merchant-side record (shows in the merchant panel and the admin panel)
  INSERT INTO public.merchant_ledger (
    merchant_user_id, entry_type, amount, direction, balance_after,
    counterparty_user_id, performed_by, performed_by_role, usd_value, profit_coins, note
  ) VALUES (
    v_me, 'reseller_recharge', p_amount, -1, v_after,
    p_reseller_id, v_me, 'merchant',
    CASE WHEN v_rate > 0 THEN round(p_amount::numeric / v_rate, 2) END,
    v_profit, NULLIF(btrim(COALESCE(p_note, '')), '')
  );

  -- Seller-side record, in the ledger the coin-seller screens already read
  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    p_reseller_id, p_amount, 'seller_package', 'coin', v_me,
    format('Coin stock received from merchant %s', v_merchant_nm)
  );

  INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
  VALUES (
    p_reseller_id,
    'Coin Stock Received',
    format('You received %s coins from merchant %s.',
           to_char(p_amount, 'FM999,999,999,999'), v_merchant_nm),
    'merchant_supply', 'coins',
    jsonb_build_object(
      'merchant_id', v_me::text,
      'merchant_name', v_merchant_nm,
      'merchant_short_id', COALESCE(v_merchant_sid, ''),
      'amount', p_amount::text,
      'currency', 'coin'
    )
  );

  RETURN json_build_object(
    'success', true,
    'message', format('Sent %s coins to %s', to_char(p_amount, 'FM999,999,999,999'), v_seller.username),
    'balance', v_after,
    'profit_coins', v_profit,
    'seller_username', v_seller.username,
    'seller_short_id', v_seller.short_id
  );
END;
$fn$;

-- ── Request a withdrawal ────────────────────────────────────────────
-- Coins are held immediately so the same balance cannot be withdrawn
-- twice while a request is pending.
CREATE OR REPLACE FUNCTION public.merchant_request_withdrawal(
  p_amount  bigint,
  p_method  text DEFAULT NULL,
  p_details text DEFAULT NULL,
  p_note    text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_me      uuid := auth.uid();
  v_stock   bigint;
  v_blocked boolean;
  v_rate    bigint;
  v_after   bigint;
  v_id      uuid;
BEGIN
  IF v_me IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not signed in');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Amount must be greater than zero');
  END IF;

  SELECT COALESCE(u.merchant_coins, 0), COALESCE(u.is_merchant_blocked, false),
         COALESCE(mp.coins_per_usd, 0)
    INTO v_stock, v_blocked, v_rate
  FROM public.users u
  LEFT JOIN public.merchant_profiles mp ON mp.user_id = u.id
  WHERE u.id = v_me AND u.is_merchant
  FOR UPDATE OF u;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'You are not an authorized merchant');
  END IF;

  IF v_blocked THEN
    RETURN json_build_object('success', false, 'message', 'Your merchant account is blocked. Contact admin.');
  END IF;

  IF v_stock < p_amount THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Insufficient balance. You hold %s coins.', to_char(v_stock, 'FM999,999,999,999'))
    );
  END IF;

  UPDATE public.users
     SET merchant_coins = COALESCE(merchant_coins, 0) - p_amount, updated_at = now()
   WHERE id = v_me
  RETURNING merchant_coins INTO v_after;

  INSERT INTO public.merchant_withdrawals (
    merchant_user_id, amount_coins, amount_usd, method, account_details, note
  ) VALUES (
    v_me, p_amount,
    CASE WHEN v_rate > 0 THEN round(p_amount::numeric / v_rate, 2) END,
    NULLIF(btrim(COALESCE(p_method, '')), ''),
    NULLIF(btrim(COALESCE(p_details, '')), ''),
    NULLIF(btrim(COALESCE(p_note, '')), '')
  ) RETURNING id INTO v_id;

  INSERT INTO public.merchant_ledger (
    merchant_user_id, entry_type, amount, direction, balance_after,
    performed_by, performed_by_role, note
  ) VALUES (
    v_me, 'withdrawal_hold', p_amount, -1, v_after, v_me, 'merchant',
    'Withdrawal requested'
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Withdrawal requested. Awaiting admin approval.',
    'withdrawal_id', v_id,
    'balance', v_after
  );
END;
$fn$;

COMMIT;
