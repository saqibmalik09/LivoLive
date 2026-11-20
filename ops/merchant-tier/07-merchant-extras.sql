-- ════════════════════════════════════════════════════════════════════
-- Merchant tier — two more things a merchant can do
--
--   1. Open a coin seller: turn a normal user into a coin seller that
--      belongs to this merchant.          (web panel only)
--   2. Recharge a normal user directly: coins land in the user's own
--      spendable balance, not seller stock. (web panel + app)
--
-- Both are additive. Nothing an existing merchant can already do changes.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Ledger gains one movement type ──────────────────────────────────
-- Opening a seller moves no coins, so it is NOT a ledger entry; it is
-- recorded in admin_audit_logs instead. Only the user recharge is money.
ALTER TABLE public.merchant_ledger
  DROP CONSTRAINT IF EXISTS merchant_ledger_entry_type_check;

ALTER TABLE public.merchant_ledger
  ADD CONSTRAINT merchant_ledger_entry_type_check CHECK (entry_type IN (
    'admin_deposit',
    'admin_deduct',
    'reseller_recharge',
    'user_recharge',        -- NEW: merchant topped up a normal user
    'withdrawal_hold',
    'withdrawal_paid',
    'withdrawal_refund',
    'adjustment'));

-- ── 1. Open a coin seller ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.merchant_open_reseller(
  p_user_id     uuid,
  p_merchant_id uuid DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_me       uuid := COALESCE(p_merchant_id, auth.uid());
  v_blocked  boolean;
  v_mname    text;
  v_target   record;
BEGIN
  IF v_me IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not signed in');
  END IF;
  IF v_me IS DISTINCT FROM auth.uid() AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT COALESCE(u.is_merchant_blocked, false), COALESCE(u.username, 'Merchant')
    INTO v_blocked, v_mname
  FROM public.users u WHERE u.id = v_me AND u.is_merchant;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'You are not an authorized merchant');
  END IF;
  IF v_blocked THEN
    RETURN json_build_object('success', false, 'message', 'Your merchant account is blocked. Contact admin.');
  END IF;

  SELECT id, COALESCE(username, 'User') AS username, short_id,
         COALESCE(is_reseller, false) AS is_reseller,
         COALESCE(is_merchant, false) AS is_merchant,
         COALESCE(is_banned, false) AS is_banned,
         merchant_id
    INTO v_target
  FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;
  IF v_target.id = v_me THEN
    RETURN json_build_object('success', false, 'message', 'You cannot open your own account as a coin seller');
  END IF;
  IF v_target.is_banned THEN
    RETURN json_build_object('success', false, 'message', 'That account is banned');
  END IF;
  IF v_target.is_merchant THEN
    RETURN json_build_object('success', false, 'message', 'That account is a merchant and cannot be a coin seller');
  END IF;
  IF v_target.is_reseller THEN
    -- Already a seller. Claim them only if no merchant has them yet.
    IF v_target.merchant_id IS NULL THEN
      UPDATE public.users SET merchant_id = v_me, updated_at = now() WHERE id = p_user_id;
      RETURN json_build_object(
        'success', true, 'message',
        format('%s was already a coin seller and is now linked to you', v_target.username),
        'linked', true);
    END IF;
    IF v_target.merchant_id = v_me THEN
      RETURN json_build_object('success', false, 'message', 'That account is already your coin seller');
    END IF;
    RETURN json_build_object('success', false, 'message', 'That account already belongs to another merchant');
  END IF;

  UPDATE public.users
     SET is_reseller = true,
         merchant_id = COALESCE(merchant_id, v_me),
         updated_at = now()
   WHERE id = p_user_id;

  INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
  VALUES (
    p_user_id,
    'You are now a Coin Seller',
    format('%s opened a coin seller account for you. Open the Reseller Panel from your profile to sell coins.', v_mname),
    'reseller_status', 'coins',
    jsonb_build_object('merchant_id', v_me::text, 'merchant_name', v_mname)
  );

  RETURN json_build_object(
    'success', true,
    'message', format('%s is now your coin seller', v_target.username),
    'user_id', v_target.id,
    'username', v_target.username,
    'short_id', v_target.short_id
  );
END;
$fn$;

-- ── 2. Recharge a normal user's ID ──────────────────────────────────
-- Coins go to users.coins (spendable), unlike a seller recharge which
-- goes to reseller_coins (stock to resell).
CREATE OR REPLACE FUNCTION public.merchant_recharge_user(
  p_user_id     uuid,
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
  v_mname       text;
  v_msid        text;
  v_target      record;
BEGIN
  IF v_me IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not signed in');
  END IF;
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
    INTO v_stock, v_blocked, v_mname, v_msid, v_limit, v_rate, v_commission
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
      'message', format('Insufficient balance. You hold %s coins.', to_char(v_stock, 'FM999,999,999,999')));
  END IF;

  SELECT id, COALESCE(username, 'User') AS username, short_id,
         COALESCE(is_banned, false) AS is_banned
    INTO v_target
  FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;
  IF v_target.id = v_me THEN
    RETURN json_build_object('success', false, 'message', 'Cannot recharge your own account');
  END IF;
  IF v_target.is_banned THEN
    RETURN json_build_object('success', false, 'message', 'That account is banned');
  END IF;

  v_profit := floor(p_amount::numeric * v_commission / 100)::bigint;

  UPDATE public.users
     SET merchant_coins = COALESCE(merchant_coins, 0) - p_amount, updated_at = now()
   WHERE id = v_me
  RETURNING merchant_coins INTO v_after;

  -- Spendable balance, not seller stock.
  UPDATE public.users
     SET coins = COALESCE(coins, 0) + p_amount, updated_at = now()
   WHERE id = p_user_id;

  INSERT INTO public.merchant_ledger (
    merchant_user_id, entry_type, amount, direction, balance_after,
    counterparty_user_id, performed_by, performed_by_role, usd_value, profit_coins, note
  ) VALUES (
    v_me, 'user_recharge', p_amount, -1, v_after,
    p_user_id, v_me, 'merchant',
    CASE WHEN v_rate > 0 THEN round(p_amount::numeric / v_rate, 2) END,
    v_profit, NULLIF(btrim(COALESCE(p_note, '')), '')
  );

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    p_user_id, p_amount, 'transfer_in', 'coin', v_me,
    format('Coins received from merchant %s', v_mname)
  );

  INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
  VALUES (
    p_user_id,
    'Coins Received',
    format('You received %s coins from merchant %s.',
           to_char(p_amount, 'FM999,999,999,999'), v_mname),
    'merchant_supply', 'coins',
    jsonb_build_object(
      'merchant_id', v_me::text, 'merchant_name', v_mname,
      'merchant_short_id', COALESCE(v_msid, ''),
      'amount', p_amount::text, 'currency', 'coin')
  );

  RETURN json_build_object(
    'success', true,
    'message', format('Sent %s coins to %s', to_char(p_amount, 'FM999,999,999,999'), v_target.username),
    'balance', v_after,
    'profit_coins', v_profit,
    'user_username', v_target.username,
    'user_short_id', v_target.short_id
  );
END;
$fn$;

-- ── 3. Search any user (for both of the above) ──────────────────────
CREATE OR REPLACE FUNCTION public.merchant_search_users(
  p_query text,
  p_limit int DEFAULT 20
) RETURNS TABLE (
  id             uuid,
  username       text,
  short_id       integer,
  avatar_url     text,
  country_code   text,
  coins          bigint,
  reseller_coins bigint,
  is_reseller    boolean,
  is_merchant    boolean,
  is_banned      boolean,
  is_mine        boolean
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
         COALESCE(u.coins, 0)::bigint, COALESCE(u.reseller_coins, 0)::bigint,
         COALESCE(u.is_reseller, false), COALESCE(u.is_merchant, false),
         COALESCE(u.is_banned, false),
         COALESCE(u.merchant_id = v_me, false)
  FROM public.users u
  WHERE (v_q ~ '^\d+$' AND u.short_id = v_q::bigint)
     OR (length(v_q) >= 2 AND u.username ILIKE '%' || v_q || '%')
  ORDER BY (v_q ~ '^\d+$' AND u.short_id = NULLIF(v_q, '')::bigint) DESC NULLS LAST, u.username
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
END;
$fn$;

COMMIT;
