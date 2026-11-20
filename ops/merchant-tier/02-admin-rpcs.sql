-- ════════════════════════════════════════════════════════════════════
-- Merchant tier — admin RPCs (main panel)
--
-- All of these require the service_role key, matching the guard used by
-- admin_fulfill_coin_seller_purchase and admin_reset_period_targets.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Make any ID a merchant / revoke it ──────────────────────────────
-- Requirement 1: "Main panel se kisi bhi ID ko merchant bana sakte hain."
CREATE OR REPLACE FUNCTION public.admin_set_merchant(
  p_user_id            uuid,
  p_enabled            boolean,
  p_commission_percent numeric DEFAULT NULL,
  p_coins_per_usd      bigint  DEFAULT NULL,
  p_credit_limit       bigint  DEFAULT NULL,
  p_display_name       text    DEFAULT NULL,
  p_contact            text    DEFAULT NULL,
  p_notes              text    DEFAULT NULL,
  p_actor_id           uuid    DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_username text;
  v_short_id integer;
  v_stock    bigint;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT username, short_id, COALESCE(merchant_coins, 0)
    INTO v_username, v_short_id, v_stock
  FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  -- Revoking is refused while stock remains, so coins cannot be stranded
  -- in a wallet nobody can reach.
  IF p_enabled IS NOT TRUE AND v_stock > 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Merchant still holds %s coins. Deduct the balance to 0 before removing merchant access.', v_stock)
    );
  END IF;

  UPDATE public.users
     SET is_merchant = COALESCE(p_enabled, false),
         is_merchant_blocked = CASE WHEN p_enabled IS TRUE THEN is_merchant_blocked ELSE false END,
         updated_at = now()
   WHERE id = p_user_id;

  IF p_enabled IS TRUE THEN
    INSERT INTO public.merchant_profiles AS mp (
      user_id, display_name, contact, commission_percent,
      coins_per_usd, credit_limit, notes, created_by
    ) VALUES (
      p_user_id,
      NULLIF(btrim(COALESCE(p_display_name, '')), ''),
      NULLIF(btrim(COALESCE(p_contact, '')), ''),
      COALESCE(p_commission_percent, 0),
      COALESCE(p_coins_per_usd, (SELECT coins_per_usd FROM public.coin_seller_policy_settings WHERE id = 1), 111760),
      COALESCE(p_credit_limit, 0),
      NULLIF(btrim(COALESCE(p_notes, '')), ''),
      p_actor_id
    )
    ON CONFLICT (user_id) DO UPDATE SET
      display_name       = COALESCE(EXCLUDED.display_name, mp.display_name),
      contact            = COALESCE(EXCLUDED.contact, mp.contact),
      commission_percent = COALESCE(p_commission_percent, mp.commission_percent),
      coins_per_usd      = COALESCE(p_coins_per_usd, mp.coins_per_usd),
      credit_limit       = COALESCE(p_credit_limit, mp.credit_limit),
      notes              = COALESCE(EXCLUDED.notes, mp.notes),
      updated_at         = now();

    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      p_user_id,
      'Merchant Access Granted',
      'Your account has been upgraded to Merchant. Open the Merchant Panel from your profile to manage coin sellers.',
      'merchant_status', 'coins',
      jsonb_build_object('is_merchant', 'true')
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', CASE WHEN p_enabled IS TRUE THEN 'Merchant enabled' ELSE 'Merchant removed' END,
    'user_id', p_user_id,
    'username', v_username,
    'short_id', v_short_id,
    'is_merchant', COALESCE(p_enabled, false)
  );
END;
$fn$;

-- ── Edit merchant settings ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_update_merchant(
  p_user_id            uuid,
  p_commission_percent numeric DEFAULT NULL,
  p_coins_per_usd      bigint  DEFAULT NULL,
  p_credit_limit       bigint  DEFAULT NULL,
  p_display_name       text    DEFAULT NULL,
  p_contact            text    DEFAULT NULL,
  p_notes              text    DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id AND is_merchant) THEN
    RETURN json_build_object('success', false, 'message', 'User is not a merchant');
  END IF;

  INSERT INTO public.merchant_profiles (user_id) VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  UPDATE public.merchant_profiles
     SET commission_percent = COALESCE(p_commission_percent, commission_percent),
         coins_per_usd      = COALESCE(p_coins_per_usd, coins_per_usd),
         credit_limit       = COALESCE(p_credit_limit, credit_limit),
         display_name       = COALESCE(NULLIF(btrim(COALESCE(p_display_name, '')), ''), display_name),
         contact            = COALESCE(NULLIF(btrim(COALESCE(p_contact, '')), ''), contact),
         notes              = COALESCE(NULLIF(btrim(COALESCE(p_notes, '')), ''), notes),
         updated_at         = now()
   WHERE user_id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'Merchant updated');
END;
$fn$;

-- ── Block / unblock ─────────────────────────────────────────────────
-- A blocked merchant keeps their balance and history but cannot supply
-- coin sellers or request withdrawals.
CREATE OR REPLACE FUNCTION public.admin_block_merchant(
  p_user_id  uuid,
  p_blocked  boolean,
  p_reason   text DEFAULT NULL,
  p_actor_id uuid DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id AND is_merchant) THEN
    RETURN json_build_object('success', false, 'message', 'User is not a merchant');
  END IF;

  UPDATE public.users
     SET is_merchant_blocked = COALESCE(p_blocked, false), updated_at = now()
   WHERE id = p_user_id;

  INSERT INTO public.merchant_profiles (user_id) VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  UPDATE public.merchant_profiles
     SET blocked_reason = CASE WHEN p_blocked THEN NULLIF(btrim(COALESCE(p_reason, '')), '') ELSE NULL END,
         blocked_at     = CASE WHEN p_blocked THEN now() ELSE NULL END,
         blocked_by     = CASE WHEN p_blocked THEN p_actor_id ELSE NULL END,
         updated_at     = now()
   WHERE user_id = p_user_id;

  INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
  VALUES (
    p_user_id,
    CASE WHEN p_blocked THEN 'Merchant Account Blocked' ELSE 'Merchant Account Restored' END,
    CASE WHEN p_blocked
         THEN COALESCE('Your merchant account has been blocked. Reason: ' || NULLIF(btrim(COALESCE(p_reason, '')), ''),
                       'Your merchant account has been blocked. Contact support for details.')
         ELSE 'Your merchant account has been unblocked. You can supply coin sellers again.' END,
    'merchant_status', 'coins',
    jsonb_build_object('blocked', CASE WHEN p_blocked THEN 'true' ELSE 'false' END)
  );

  RETURN json_build_object(
    'success', true,
    'message', CASE WHEN p_blocked THEN 'Merchant blocked' ELSE 'Merchant unblocked' END
  );
END;
$fn$;

-- ── Recharge / remove merchant coins ────────────────────────────────
-- Requirement 2: admin can recharge AND remove coins.
-- Requirement 3: every movement is recorded, for the admin and the merchant.
-- Positive p_amount credits, negative debits.
CREATE OR REPLACE FUNCTION public.admin_adjust_merchant_coins(
  p_user_id  uuid,
  p_amount   bigint,
  p_note     text DEFAULT NULL,
  p_actor_id uuid DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_stock    bigint;
  v_after    bigint;
  v_abs      bigint;
  v_rate     bigint;
  v_type     text;
  v_dir      smallint;
  v_username text;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_amount IS NULL OR p_amount = 0 THEN
    RETURN json_build_object('success', false, 'message', 'Amount must not be zero');
  END IF;

  SELECT COALESCE(merchant_coins, 0), username INTO v_stock, v_username
  FROM public.users WHERE id = p_user_id AND is_merchant FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Merchant not found');
  END IF;

  v_abs  := abs(p_amount);
  v_dir  := CASE WHEN p_amount > 0 THEN 1 ELSE -1 END;
  v_type := CASE WHEN p_amount > 0 THEN 'admin_deposit' ELSE 'admin_deduct' END;

  IF v_dir = -1 AND v_stock < v_abs THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Merchant holds only %s coins', v_stock)
    );
  END IF;

  UPDATE public.users
     SET merchant_coins = COALESCE(merchant_coins, 0) + p_amount, updated_at = now()
   WHERE id = p_user_id
  RETURNING merchant_coins INTO v_after;

  SELECT coins_per_usd INTO v_rate FROM public.merchant_profiles WHERE user_id = p_user_id;

  INSERT INTO public.merchant_ledger (
    merchant_user_id, entry_type, amount, direction, balance_after,
    performed_by, performed_by_role, usd_value, note
  ) VALUES (
    p_user_id, v_type, v_abs, v_dir, v_after,
    p_actor_id, 'admin',
    CASE WHEN COALESCE(v_rate, 0) > 0 THEN round(v_abs::numeric / v_rate, 2) END,
    NULLIF(btrim(COALESCE(p_note, '')), '')
  );

  INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
  VALUES (
    p_user_id,
    CASE WHEN v_dir = 1 THEN 'Merchant Wallet Recharged' ELSE 'Merchant Wallet Debited' END,
    format(
      CASE WHEN v_dir = 1
           THEN 'Your merchant wallet was recharged with %s coins. New balance: %s.'
           ELSE '%s coins were removed from your merchant wallet. New balance: %s.' END,
      to_char(v_abs, 'FM999,999,999,999'), to_char(v_after, 'FM999,999,999,999')
    ),
    'merchant_wallet', 'coins',
    jsonb_build_object('amount', v_abs::text, 'direction', v_dir::text, 'balance', v_after::text)
  );

  RETURN json_build_object(
    'success', true,
    'message', CASE WHEN v_dir = 1 THEN 'Merchant recharged' ELSE 'Coins removed' END,
    'balance', v_after
  );
END;
$fn$;

-- ── Approve / reject a merchant withdrawal ──────────────────────────
CREATE OR REPLACE FUNCTION public.admin_process_merchant_withdrawal(
  p_withdrawal_id uuid,
  p_status        text,
  p_admin_note    text DEFAULT NULL,
  p_actor_id      uuid DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  w       record;
  v_after bigint;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_status NOT IN ('approved', 'rejected', 'paid') THEN
    RETURN json_build_object('success', false, 'message', 'Status must be approved, rejected or paid');
  END IF;

  SELECT * INTO w FROM public.merchant_withdrawals WHERE id = p_withdrawal_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Withdrawal not found');
  END IF;

  IF w.status <> 'pending' AND NOT (w.status = 'approved' AND p_status = 'paid') THEN
    RETURN json_build_object('success', false, 'message', format('Withdrawal is already %s', w.status));
  END IF;

  -- Coins were held at request time; rejecting returns them.
  IF p_status = 'rejected' THEN
    UPDATE public.users
       SET merchant_coins = COALESCE(merchant_coins, 0) + w.amount_coins, updated_at = now()
     WHERE id = w.merchant_user_id
    RETURNING merchant_coins INTO v_after;

    INSERT INTO public.merchant_ledger (
      merchant_user_id, entry_type, amount, direction, balance_after,
      performed_by, performed_by_role, note
    ) VALUES (
      w.merchant_user_id, 'withdrawal_refund', w.amount_coins, 1, v_after,
      p_actor_id, 'admin',
      COALESCE(NULLIF(btrim(COALESCE(p_admin_note, '')), ''), 'Withdrawal rejected')
    );
  ELSIF p_status = 'paid' THEN
    SELECT COALESCE(merchant_coins, 0) INTO v_after
    FROM public.users WHERE id = w.merchant_user_id;

    INSERT INTO public.merchant_ledger (
      merchant_user_id, entry_type, amount, direction, balance_after,
      performed_by, performed_by_role, usd_value, note
    ) VALUES (
      w.merchant_user_id, 'withdrawal_paid', w.amount_coins, -1, v_after,
      p_actor_id, 'admin', w.amount_usd,
      COALESCE(NULLIF(btrim(COALESCE(p_admin_note, '')), ''), 'Withdrawal paid')
    );
  END IF;

  UPDATE public.merchant_withdrawals
     SET status       = p_status,
         admin_note   = COALESCE(NULLIF(btrim(COALESCE(p_admin_note, '')), ''), admin_note),
         processed_by = p_actor_id,
         processed_at = now()
   WHERE id = p_withdrawal_id;

  INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
  VALUES (
    w.merchant_user_id,
    format('Withdrawal %s', initcap(p_status)),
    format('Your withdrawal of %s coins was %s.', to_char(w.amount_coins, 'FM999,999,999,999'), p_status),
    'merchant_withdrawal', 'coins',
    jsonb_build_object('withdrawal_id', p_withdrawal_id::text, 'status', p_status)
  );

  RETURN json_build_object('success', true, 'message', format('Withdrawal %s', p_status));
END;
$fn$;

COMMIT;
