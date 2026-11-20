import { supabaseAdmin } from "@/lib/supabase";
import "server-only";

/**
 * Reads for the merchant panel.
 *
 * Every function takes the merchant's user id explicitly and callers must
 * pass the one from `getMerchantActor()`. The underlying RPCs accept any
 * merchant id when called with the service-role key, so scoping is this
 * panel's responsibility — never pass an id that came from the client.
 */

export type Overview = {
  success: boolean;
  message?: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  display_name: string | null;
  contact: string | null;
  is_blocked: boolean;
  blocked_reason: string | null;
  wallet_balance: number;
  commission_percent: number;
  coins_per_usd: number;
  credit_limit: number;
  total_sales: number;
  total_profit: number;
  total_deposited: number;
  total_deducted: number;
  total_withdrawn: number;
  pending_withdrawal_coins: number;
  pending_withdrawal_count: number;
  seller_count: number;
  sales_usd: number;
  profit_usd: number;
  balance_usd: number;
};

export type LedgerRow = {
  id: string;
  entry_type: string;
  amount: number;
  direction: number;
  balance_after: number;
  usd_value: number | null;
  profit_coins: number;
  note: string | null;
  performed_by_role: string;
  created_at: string;
  counterparty_id: string | null;
  counterparty_name: string | null;
  counterparty_sid: number | null;
  counterparty_avatar: string | null;
};

export type SellerRow = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  country_code: string | null;
  reseller_coins: number;
  is_banned: boolean;
  is_linked: boolean;
  total_supplied: number;
  supply_count: number;
  last_supplied_at: string | null;
};

export type WithdrawalRow = {
  id: string;
  amount_coins: number;
  amount_usd: number | null;
  method: string | null;
  account_details: string | null;
  status: string;
  note: string | null;
  admin_note: string | null;
  requested_at: string;
  processed_at: string | null;
};

export async function getOverview(userId: string): Promise<Overview | null> {
  const { data, error } = await supabaseAdmin.rpc("get_merchant_overview", {
    p_user_id: userId,
  });
  if (error) {
    console.error("[merchant-panel] overview", error.message);
    return null;
  }
  const o = data as Overview | null;
  return o && o.success ? o : null;
}

export async function getLedger(
  userId: string,
  type: string | null = null,
  limit = 100,
): Promise<LedgerRow[]> {
  const { data, error } = await supabaseAdmin.rpc("get_merchant_ledger", {
    p_user_id: userId,
    p_type: type,
    p_limit: limit,
  });
  if (error) {
    console.error("[merchant-panel] ledger", error.message);
    return [];
  }
  return (data as LedgerRow[]) ?? [];
}

export async function getSellers(userId: string): Promise<SellerRow[]> {
  const { data, error } = await supabaseAdmin.rpc("get_merchant_resellers", {
    p_user_id: userId,
  });
  if (error) {
    console.error("[merchant-panel] sellers", error.message);
    return [];
  }
  return (data as SellerRow[]) ?? [];
}

export async function getWithdrawals(userId: string): Promise<WithdrawalRow[]> {
  const { data, error } = await supabaseAdmin.rpc("get_merchant_withdrawals", {
    p_user_id: userId,
  });
  if (error) {
    console.error("[merchant-panel] withdrawals", error.message);
    return [];
  }
  return (data as WithdrawalRow[]) ?? [];
}

/**
 * Coin-seller lookup. `merchant_search_coin_sellers` scopes itself to
 * `auth.uid()`, which is absent on a service-role connection, so the panel
 * queries `users` directly with the same filter the RPC applies.
 */
export async function searchCoinSellers(
  merchantUserId: string,
  query: string,
  limit = 20,
): Promise<SellerRow[]> {
  const q = query.trim();
  if (!q) return [];
  const numeric = /^\d+$/.test(q);
  if (!numeric && q.length < 2) return [];

  let sel = supabaseAdmin
    .from("users")
    .select(
      "id, username, short_id, avatar_url, country_code, reseller_coins, is_banned, merchant_id",
    )
    .eq("is_reseller", true)
    .limit(limit);

  sel = numeric ? sel.eq("short_id", Number(q)) : sel.ilike("username", `%${q}%`);

  const { data, error } = await sel;
  if (error) {
    console.error("[merchant-panel] search", error.message);
    return [];
  }
  return ((data as Record<string, unknown>[]) ?? []).map((r) => ({
    id: String(r.id),
    username: (r.username as string) ?? null,
    short_id: (r.short_id as number) ?? null,
    avatar_url: (r.avatar_url as string) ?? null,
    country_code: (r.country_code as string) ?? null,
    reseller_coins: Number(r.reseller_coins ?? 0),
    is_banned: r.is_banned === true,
    is_linked: r.merchant_id === merchantUserId,
    total_supplied: 0,
    supply_count: 0,
    last_supplied_at: null,
  }));
}

export type UserRow = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  country_code: string | null;
  coins: number;
  reseller_coins: number;
  is_reseller: boolean;
  is_merchant: boolean;
  is_banned: boolean;
  is_mine: boolean;
};

/**
 * Search any account — used both for topping up a normal user's ID and for
 * opening a new coin seller. Mirrors `merchant_search_users`, which scopes
 * itself to `auth.uid()` and so returns nothing on a service-role connection.
 */
export async function searchAnyUsers(
  merchantUserId: string,
  query: string,
  limit = 20,
): Promise<UserRow[]> {
  const q = query.trim();
  if (!q) return [];
  const numeric = /^\d+$/.test(q);
  if (!numeric && q.length < 2) return [];

  let sel = supabaseAdmin
    .from("users")
    .select(
      "id, username, short_id, avatar_url, country_code, coins, reseller_coins, is_reseller, is_merchant, is_banned, merchant_id",
    )
    .limit(limit);

  sel = numeric ? sel.eq("short_id", Number(q)) : sel.ilike("username", `%${q}%`);

  const { data, error } = await sel;
  if (error) {
    console.error("[merchant-panel] user search", error.message);
    return [];
  }
  return ((data as Record<string, unknown>[]) ?? []).map((r) => ({
    id: String(r.id),
    username: (r.username as string) ?? null,
    short_id: (r.short_id as number) ?? null,
    avatar_url: (r.avatar_url as string) ?? null,
    country_code: (r.country_code as string) ?? null,
    coins: Number(r.coins ?? 0),
    reseller_coins: Number(r.reseller_coins ?? 0),
    is_reseller: r.is_reseller === true,
    is_merchant: r.is_merchant === true,
    is_banned: r.is_banned === true,
    is_mine: r.merchant_id === merchantUserId,
  }));
}

export const ENTRY_LABELS: Record<string, string> = {
  admin_deposit: "Admin recharge",
  admin_deduct: "Admin deduction",
  reseller_recharge: "Sold to coin seller",
  user_recharge: "Recharged a user",
  withdrawal_hold: "Withdrawal requested",
  withdrawal_paid: "Withdrawal paid",
  withdrawal_refund: "Withdrawal refunded",
  adjustment: "Adjustment",
};

export const fmtCoins = (v: number | null | undefined) =>
  (v ?? 0).toLocaleString();

export function fmtDate(iso: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString(undefined, {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}
