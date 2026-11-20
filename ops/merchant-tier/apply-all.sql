-- ════════════════════════════════════════════════════════════════
-- Merchant tier — complete migration, in order.
-- Regenerated 2026-10-07 00:45. Safe to re-run.
-- ════════════════════════════════════════════════════════════════

-- ─────────── 01-schema.sql ───────────
-- ════════════════════════════════════════════════════════════════════
-- Merchant tier — schema
--
-- Adds a wholesale tier above the existing coin sellers:
--     Admin  →  Merchant  →  Coin Seller (users.is_reseller)  →  User
--
-- Follows the existing convention of flagging the tier on `users`
-- (is_reseller / reseller_coins), with the richer bookkeeping in its
-- own tables. Nothing here alters an existing column or constraint.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Tier flags on users ──────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_merchant         boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS merchant_coins      bigint  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_merchant_blocked boolean NOT NULL DEFAULT false,
  -- which merchant a coin seller belongs to (null = direct/admin-supplied)
  ADD COLUMN IF NOT EXISTS merchant_id         uuid REFERENCES public.users(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.users.is_merchant IS
  'Wholesale tier above coin sellers. Set via admin_set_merchant().';
COMMENT ON COLUMN public.users.merchant_coins IS
  'Merchant wholesale stock. Distinct from coins (spendable) and reseller_coins (coin-seller stock).';
COMMENT ON COLUMN public.users.merchant_id IS
  'For a coin seller: the merchant who supplies them.';

CREATE INDEX IF NOT EXISTS users_is_merchant_idx
  ON public.users (is_merchant) WHERE is_merchant = true;
CREATE INDEX IF NOT EXISTS users_merchant_id_idx
  ON public.users (merchant_id) WHERE merchant_id IS NOT NULL;

-- ── 2. Merchant settings / metadata ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.merchant_profiles (
  user_id            uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  display_name       text,
  contact            text,
  -- margin the merchant earns on coins sold down to their coin sellers
  commission_percent numeric NOT NULL DEFAULT 0 CHECK (commission_percent >= 0 AND commission_percent <= 100),
  -- the merchant's own buy rate, for USD valuation of deposits/sales
  coins_per_usd      bigint  NOT NULL DEFAULT 111760 CHECK (coins_per_usd > 0),
  -- allows selling beyond wallet balance when > 0 (0 = strictly prepaid)
  credit_limit       bigint  NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
  notes              text,
  blocked_reason     text,
  blocked_at         timestamptz,
  blocked_by         uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_by         uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

-- ── 3. Ledger — one row per movement, read by admin AND merchant ────
CREATE TABLE IF NOT EXISTS public.merchant_ledger (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  entry_type           text NOT NULL CHECK (entry_type IN (
                         'admin_deposit',      -- admin recharged the merchant
                         'admin_deduct',       -- admin removed coins
                         'reseller_recharge',  -- merchant supplied a coin seller
                         'withdrawal_hold',    -- withdrawal requested, coins held
                         'withdrawal_paid',    -- withdrawal settled
                         'withdrawal_refund',  -- withdrawal rejected, coins returned
                         'adjustment')),
  amount               bigint NOT NULL CHECK (amount > 0),
  direction            smallint NOT NULL CHECK (direction IN (-1, 1)),
  balance_after        bigint NOT NULL,
  counterparty_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  performed_by         uuid REFERENCES public.users(id) ON DELETE SET NULL,
  performed_by_role    text NOT NULL DEFAULT 'system'
                         CHECK (performed_by_role IN ('admin', 'merchant', 'system')),
  usd_value            numeric,
  -- margin earned on this row, frozen at the rate in force at the time
  profit_coins         bigint NOT NULL DEFAULT 0,
  note                 text,
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS merchant_ledger_merchant_idx
  ON public.merchant_ledger (merchant_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS merchant_ledger_type_idx
  ON public.merchant_ledger (merchant_user_id, entry_type, created_at DESC);
CREATE INDEX IF NOT EXISTS merchant_ledger_counterparty_idx
  ON public.merchant_ledger (counterparty_user_id, created_at DESC)
  WHERE counterparty_user_id IS NOT NULL;

-- ── 4. Withdrawals ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.merchant_withdrawals (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount_coins     bigint NOT NULL CHECK (amount_coins > 0),
  amount_usd       numeric,
  method           text,
  account_details  text,
  status           text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'approved', 'rejected', 'paid')),
  note             text,
  admin_note       text,
  requested_at     timestamptz NOT NULL DEFAULT now(),
  processed_by     uuid REFERENCES public.users(id) ON DELETE SET NULL,
  processed_at     timestamptz
);

CREATE INDEX IF NOT EXISTS merchant_withdrawals_merchant_idx
  ON public.merchant_withdrawals (merchant_user_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS merchant_withdrawals_pending_idx
  ON public.merchant_withdrawals (status, requested_at DESC) WHERE status = 'pending';

-- ── 5. RLS — merchants read their own rows, nothing else ────────────
-- Every mutation goes through a SECURITY DEFINER function, so no
-- insert/update/delete policy is granted to end users here.
ALTER TABLE public.merchant_profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_ledger      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_withdrawals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS merchant_profiles_own_read ON public.merchant_profiles;
CREATE POLICY merchant_profiles_own_read ON public.merchant_profiles
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS merchant_ledger_own_read ON public.merchant_ledger;
CREATE POLICY merchant_ledger_own_read ON public.merchant_ledger
  FOR SELECT USING (merchant_user_id = auth.uid() OR counterparty_user_id = auth.uid());

DROP POLICY IF EXISTS merchant_withdrawals_own_read ON public.merchant_withdrawals;
CREATE POLICY merchant_withdrawals_own_read ON public.merchant_withdrawals
  FOR SELECT USING (merchant_user_id = auth.uid());

COMMIT;

-- ─────────── 02-admin-rpcs.sql ───────────
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

-- ─────────── 03-merchant-rpcs.sql ───────────
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

-- ─────────── 04-read-rpcs.sql ───────────
-- ════════════════════════════════════════════════════════════════════
-- Merchant tier — read RPCs
--
-- Each one answers for the caller's own merchant account, or for any
-- merchant when called with the service_role key (the admin panel).
-- Requirement 3: the same records are visible to the merchant and admin.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Headline figures for the merchant panel / admin detail page ─────
CREATE OR REPLACE FUNCTION public.get_merchant_overview(p_user_id uuid DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_target uuid := COALESCE(p_user_id, auth.uid());
  u        record;
  v_sales       bigint := 0;
  v_profit      bigint := 0;
  v_deposited   bigint := 0;
  v_deducted    bigint := 0;
  v_withdrawn   bigint := 0;
  v_pending     bigint := 0;
  v_pending_cnt int := 0;
  v_sellers     int := 0;
BEGIN
  IF v_target IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not signed in');
  END IF;

  IF v_target IS DISTINCT FROM auth.uid() AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT u2.id, u2.username, u2.short_id, u2.avatar_url, u2.country_code,
         COALESCE(u2.merchant_coins, 0) AS merchant_coins,
         COALESCE(u2.is_merchant, false) AS is_merchant,
         COALESCE(u2.is_merchant_blocked, false) AS is_blocked,
         COALESCE(mp.commission_percent, 0) AS commission_percent,
         COALESCE(mp.coins_per_usd, 0) AS coins_per_usd,
         COALESCE(mp.credit_limit, 0) AS credit_limit,
         mp.display_name, mp.contact, mp.notes, mp.blocked_reason, mp.created_at
    INTO u
  FROM public.users u2
  LEFT JOIN public.merchant_profiles mp ON mp.user_id = u2.id
  WHERE u2.id = v_target;

  IF NOT FOUND OR u.is_merchant IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'Not a merchant account');
  END IF;

  SELECT
    COALESCE(SUM(amount) FILTER (WHERE entry_type IN ('reseller_recharge', 'user_recharge')), 0),
    COALESCE(SUM(profit_coins) FILTER (WHERE entry_type IN ('reseller_recharge', 'user_recharge')), 0),
    COALESCE(SUM(amount) FILTER (WHERE entry_type = 'admin_deposit'), 0),
    COALESCE(SUM(amount) FILTER (WHERE entry_type = 'admin_deduct'), 0),
    COALESCE(SUM(amount) FILTER (WHERE entry_type = 'withdrawal_paid'), 0)
  INTO v_sales, v_profit, v_deposited, v_deducted, v_withdrawn
  FROM public.merchant_ledger WHERE merchant_user_id = v_target;

  SELECT COALESCE(SUM(amount_coins), 0), COUNT(*)
    INTO v_pending, v_pending_cnt
  FROM public.merchant_withdrawals
  WHERE merchant_user_id = v_target AND status IN ('pending', 'approved');

  SELECT COUNT(DISTINCT s) INTO v_sellers FROM (
    SELECT counterparty_user_id AS s FROM public.merchant_ledger
     WHERE merchant_user_id = v_target AND entry_type = 'reseller_recharge'
       AND counterparty_user_id IS NOT NULL
    UNION
    SELECT id FROM public.users WHERE merchant_id = v_target AND is_reseller
  ) q;

  RETURN json_build_object(
    'success', true,
    'user_id', u.id,
    'username', u.username,
    'short_id', u.short_id,
    'avatar_url', u.avatar_url,
    'country_code', u.country_code,
    'display_name', u.display_name,
    'contact', u.contact,
    'notes', u.notes,
    'is_blocked', u.is_blocked,
    'blocked_reason', u.blocked_reason,
    'merchant_since', u.created_at,
    'wallet_balance', u.merchant_coins,
    'commission_percent', u.commission_percent,
    'coins_per_usd', u.coins_per_usd,
    'credit_limit', u.credit_limit,
    'total_sales', v_sales,
    'total_profit', v_profit,
    'total_deposited', v_deposited,
    'total_deducted', v_deducted,
    'total_withdrawn', v_withdrawn,
    'pending_withdrawal_coins', v_pending,
    'pending_withdrawal_count', v_pending_cnt,
    'seller_count', v_sellers,
    'sales_usd', CASE WHEN u.coins_per_usd > 0 THEN round(v_sales::numeric / u.coins_per_usd, 2) ELSE 0 END,
    'profit_usd', CASE WHEN u.coins_per_usd > 0 THEN round(v_profit::numeric / u.coins_per_usd, 2) ELSE 0 END,
    'balance_usd', CASE WHEN u.coins_per_usd > 0 THEN round(u.merchant_coins::numeric / u.coins_per_usd, 2) ELSE 0 END
  );
END;
$fn$;

-- ── Full transaction history ────────────────────────────────────────
-- p_type: null = everything, or one entry_type, or 'deposits' for the
-- admin recharge/deduct pair (the "deposit history" view).
CREATE OR REPLACE FUNCTION public.get_merchant_ledger(
  p_user_id uuid DEFAULT NULL,
  p_type    text DEFAULT NULL,
  p_limit   int  DEFAULT 50,
  p_offset  int  DEFAULT 0
) RETURNS TABLE (
  id                 uuid,
  entry_type         text,
  amount             bigint,
  direction          smallint,
  balance_after      bigint,
  usd_value          numeric,
  profit_coins       bigint,
  note               text,
  performed_by_role  text,
  created_at         timestamptz,
  counterparty_id    uuid,
  counterparty_name  text,
  counterparty_sid   integer,
  counterparty_avatar text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_target uuid := COALESCE(p_user_id, auth.uid());
BEGIN
  IF v_target IS NULL THEN RETURN; END IF;
  IF v_target IS DISTINCT FROM auth.uid() AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT l.id, l.entry_type, l.amount, l.direction, l.balance_after,
         l.usd_value, l.profit_coins, l.note, l.performed_by_role, l.created_at,
         c.id, c.username, c.short_id, c.avatar_url
  FROM public.merchant_ledger l
  LEFT JOIN public.users c ON c.id = l.counterparty_user_id
  WHERE l.merchant_user_id = v_target
    AND (
      p_type IS NULL
      OR (p_type = 'deposits' AND l.entry_type IN ('admin_deposit', 'admin_deduct'))
      OR (p_type = 'sales'    AND l.entry_type IN ('reseller_recharge', 'user_recharge'))
      OR (p_type = 'withdrawals' AND l.entry_type IN ('withdrawal_hold', 'withdrawal_paid', 'withdrawal_refund'))
      OR l.entry_type = p_type
    )
  ORDER BY l.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 200))
  OFFSET GREATEST(0, COALESCE(p_offset, 0));
END;
$fn$;

-- ── The merchant's coin sellers ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_merchant_resellers(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
  id              uuid,
  username        text,
  short_id        integer,
  avatar_url      text,
  country_code    text,
  reseller_coins  bigint,
  is_banned       boolean,
  is_linked       boolean,
  total_supplied  bigint,
  supply_count    bigint,
  last_supplied_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_target uuid := COALESCE(p_user_id, auth.uid());
BEGIN
  IF v_target IS NULL THEN RETURN; END IF;
  IF v_target IS DISTINCT FROM auth.uid() AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH supplied AS (
    SELECT l.counterparty_user_id AS seller_id,
           SUM(l.amount)::bigint AS total_supplied,
           COUNT(*)       AS supply_count,
           MAX(l.created_at) AS last_supplied_at
    FROM public.merchant_ledger l
    WHERE l.merchant_user_id = v_target
      AND l.entry_type = 'reseller_recharge'
      AND l.counterparty_user_id IS NOT NULL
    GROUP BY 1
  ),
  roster AS (
    SELECT seller_id FROM supplied
    UNION
    SELECT u.id FROM public.users u WHERE u.merchant_id = v_target AND u.is_reseller
  )
  SELECT u.id, u.username, u.short_id, u.avatar_url, u.country_code,
         COALESCE(u.reseller_coins, 0), COALESCE(u.is_banned, false),
         COALESCE(u.merchant_id = v_target, false),
         COALESCE(s.total_supplied, 0)::bigint, COALESCE(s.supply_count, 0)::bigint, s.last_supplied_at
  FROM roster r
  JOIN public.users u ON u.id = r.seller_id
  LEFT JOIN supplied s ON s.seller_id = r.seller_id
  ORDER BY s.last_supplied_at DESC NULLS LAST, u.username;
END;
$fn$;

-- ── Withdrawal requests ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_merchant_withdrawals(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
  id              uuid,
  amount_coins    bigint,
  amount_usd      numeric,
  method          text,
  account_details text,
  status          text,
  note            text,
  admin_note      text,
  requested_at    timestamptz,
  processed_at    timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_target uuid := COALESCE(p_user_id, auth.uid());
BEGIN
  IF v_target IS NULL THEN RETURN; END IF;
  IF v_target IS DISTINCT FROM auth.uid() AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT w.id, w.amount_coins, w.amount_usd, w.method, w.account_details,
         w.status, w.note, w.admin_note, w.requested_at, w.processed_at
  FROM public.merchant_withdrawals w
  WHERE w.merchant_user_id = v_target
  ORDER BY w.requested_at DESC;
END;
$fn$;

-- ── Admin: list every merchant with their figures ───────────────────
CREATE OR REPLACE FUNCTION public.admin_list_merchants(
  p_query  text DEFAULT NULL,
  p_limit  int  DEFAULT 100,
  p_offset int  DEFAULT 0
) RETURNS TABLE (
  id                 uuid,
  username           text,
  short_id           integer,
  avatar_url         text,
  country_code       text,
  display_name       text,
  contact            text,
  wallet_balance     bigint,
  is_blocked         boolean,
  blocked_reason     text,
  commission_percent numeric,
  coins_per_usd      bigint,
  credit_limit       bigint,
  total_sales        bigint,
  total_profit       bigint,
  total_deposited    bigint,
  total_withdrawn    bigint,
  seller_count       bigint,
  pending_withdrawals bigint,
  merchant_since     timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_q text := btrim(COALESCE(p_query, ''));
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RETURN; END IF;

  RETURN QUERY
  SELECT u.id, u.username, u.short_id, u.avatar_url, u.country_code,
         mp.display_name, mp.contact,
         COALESCE(u.merchant_coins, 0),
         COALESCE(u.is_merchant_blocked, false),
         mp.blocked_reason,
         COALESCE(mp.commission_percent, 0),
         COALESCE(mp.coins_per_usd, 0),
         COALESCE(mp.credit_limit, 0),
         COALESCE(agg.sales, 0)::bigint,
         COALESCE(agg.profit, 0)::bigint,
         COALESCE(agg.deposited, 0)::bigint,
         COALESCE(agg.withdrawn, 0)::bigint,
         COALESCE(sellers.cnt, 0)::bigint,
         COALESCE(pend.cnt, 0)::bigint,
         mp.created_at
  FROM public.users u
  LEFT JOIN public.merchant_profiles mp ON mp.user_id = u.id
  LEFT JOIN LATERAL (
    SELECT SUM(amount) FILTER (WHERE entry_type IN ('reseller_recharge', 'user_recharge')) AS sales,
           SUM(profit_coins) FILTER (WHERE entry_type IN ('reseller_recharge', 'user_recharge')) AS profit,
           SUM(amount) FILTER (WHERE entry_type = 'admin_deposit') AS deposited,
           SUM(amount) FILTER (WHERE entry_type = 'withdrawal_paid') AS withdrawn
    FROM public.merchant_ledger WHERE merchant_user_id = u.id
  ) agg ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(DISTINCT s) AS cnt FROM (
      SELECT counterparty_user_id AS s FROM public.merchant_ledger
       WHERE merchant_user_id = u.id AND entry_type = 'reseller_recharge'
         AND counterparty_user_id IS NOT NULL
      UNION
      SELECT r.id FROM public.users r WHERE r.merchant_id = u.id AND r.is_reseller
    ) x
  ) sellers ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*) AS cnt FROM public.merchant_withdrawals
     WHERE merchant_user_id = u.id AND status = 'pending'
  ) pend ON true
  WHERE u.is_merchant = true
    AND (
      v_q = ''
      OR (v_q ~ '^\d+$' AND u.short_id = v_q::bigint)
      OR u.username ILIKE '%' || v_q || '%'
      OR mp.display_name ILIKE '%' || v_q || '%'
    )
  ORDER BY COALESCE(agg.sales, 0) DESC, u.username
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500))
  OFFSET GREATEST(0, COALESCE(p_offset, 0));
END;
$fn$;

-- ── Admin: find any user to promote to merchant ─────────────────────
CREATE OR REPLACE FUNCTION public.admin_search_users_for_merchant(
  p_query text,
  p_limit int DEFAULT 20
) RETURNS TABLE (
  id           uuid,
  username     text,
  short_id     integer,
  avatar_url   text,
  country_code text,
  coins        bigint,
  is_merchant  boolean,
  is_reseller  boolean,
  is_banned    boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_q text := btrim(COALESCE(p_query, ''));
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RETURN; END IF;
  IF v_q = '' THEN RETURN; END IF;

  RETURN QUERY
  SELECT u.id, u.username, u.short_id, u.avatar_url, u.country_code,
         COALESCE(u.coins, 0), COALESCE(u.is_merchant, false),
         COALESCE(u.is_reseller, false), COALESCE(u.is_banned, false)
  FROM public.users u
  WHERE (v_q ~ '^\d+$' AND u.short_id = v_q::bigint)
     OR (length(v_q) >= 2 AND u.username ILIKE '%' || v_q || '%')
  ORDER BY (v_q ~ '^\d+$' AND u.short_id = NULLIF(v_q, '')::bigint) DESC NULLS LAST, u.username
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
END;
$fn$;

-- ── Admin: every pending merchant withdrawal across merchants ───────
CREATE OR REPLACE FUNCTION public.admin_list_merchant_withdrawals(
  p_status text DEFAULT NULL,
  p_limit  int  DEFAULT 100
) RETURNS TABLE (
  id              uuid,
  merchant_id     uuid,
  merchant_name   text,
  merchant_sid    integer,
  amount_coins    bigint,
  amount_usd      numeric,
  method          text,
  account_details text,
  status          text,
  note            text,
  admin_note      text,
  requested_at    timestamptz,
  processed_at    timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RETURN; END IF;

  RETURN QUERY
  SELECT w.id, w.merchant_user_id, u.username, u.short_id,
         w.amount_coins, w.amount_usd, w.method, w.account_details,
         w.status, w.note, w.admin_note, w.requested_at, w.processed_at
  FROM public.merchant_withdrawals w
  JOIN public.users u ON u.id = w.merchant_user_id
  WHERE p_status IS NULL OR w.status = p_status
  ORDER BY (w.status = 'pending') DESC, w.requested_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$fn$;

COMMIT;

