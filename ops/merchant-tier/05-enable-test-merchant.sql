-- ════════════════════════════════════════════════════════════════════
-- Turn one account into a merchant so the in-app panel can be tested.
--
--   psql … -v sid=123456 -v coins=5000000 -f 05-enable-test-merchant.sql
--
--   sid   = the numeric app ID of the account you log in with
--   coins = test float for its merchant wallet (0 to skip funding)
--
-- Run AFTER apply-all.sql. Re-runnable: funding adds each time, the
-- merchant flag and profile are simply re-asserted.
-- ════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP on
\pset pager off

-- Carry the psql variables into the session so the DO block can read
-- them; psql does not substitute :vars inside dollar-quoted bodies.
SELECT set_config('merchant_test.sid', :'sid', false),
       set_config('merchant_test.coins', :'coins', false) \gset dummy_

DO $test$
DECLARE
  v_sid   bigint := current_setting('merchant_test.sid')::bigint;
  v_coins bigint := current_setting('merchant_test.coins')::bigint;
  v_id    uuid;
  v_name  text;
  v_bal   bigint;
BEGIN
  SELECT id, COALESCE(username, 'User') INTO v_id, v_name
  FROM public.users WHERE short_id = v_sid;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'No user with app ID %', v_sid;
  END IF;

  -- Mark as merchant, mirroring what admin_set_merchant does.
  UPDATE public.users
     SET is_merchant = true, is_merchant_blocked = false, updated_at = now()
   WHERE id = v_id;

  INSERT INTO public.merchant_profiles (
    user_id, commission_percent, coins_per_usd, credit_limit, notes
  ) VALUES (
    v_id, 10,
    COALESCE((SELECT coins_per_usd FROM public.coin_seller_policy_settings WHERE id = 1), 111760),
    0, 'test merchant'
  )
  ON CONFLICT (user_id) DO UPDATE
    SET commission_percent = 10, updated_at = now();

  -- Fund the wallet, recorded the way an admin recharge would be.
  IF v_coins > 0 THEN
    UPDATE public.users
       SET merchant_coins = COALESCE(merchant_coins, 0) + v_coins, updated_at = now()
     WHERE id = v_id
    RETURNING merchant_coins INTO v_bal;

    INSERT INTO public.merchant_ledger (
      merchant_user_id, entry_type, amount, direction, balance_after,
      performed_by_role, note
    ) VALUES (
      v_id, 'admin_deposit', v_coins, 1, v_bal, 'admin', 'test float'
    );
  ELSE
    SELECT COALESCE(merchant_coins, 0) INTO v_bal
    FROM public.users WHERE id = v_id;
  END IF;

  RAISE NOTICE 'Merchant enabled: % (ID %) — wallet balance % coins', v_name, v_sid, v_bal;
END
$test$;

\echo '── the merchant account ──'
SELECT username, short_id, is_merchant, merchant_coins, is_merchant_blocked
FROM public.users WHERE short_id = :sid;

\echo '── coin sellers you can recharge from the panel ──'
SELECT username AS coin_seller, short_id, reseller_coins
FROM public.users WHERE is_reseller = true
ORDER BY reseller_coins DESC LIMIT 10;
