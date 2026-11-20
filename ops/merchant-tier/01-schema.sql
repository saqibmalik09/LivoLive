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
