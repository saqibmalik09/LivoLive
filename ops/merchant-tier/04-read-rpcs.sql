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
