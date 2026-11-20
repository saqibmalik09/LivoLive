import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Store } from "lucide-react";
import { MerchantDetailClient } from "./MerchantDetailClient";

export const dynamic = "force-dynamic";

export type Overview = {
  success: boolean;
  message?: string;
  user_id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  country_code: string | null;
  display_name: string | null;
  contact: string | null;
  notes: string | null;
  is_blocked: boolean;
  blocked_reason: string | null;
  merchant_since: string | null;
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

export type PanelLogin = {
  username: string;
  is_active: boolean;
  must_change_password: boolean;
  last_login_at: string | null;
  locked_until: string | null;
  live_sessions: number;
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

export default async function MerchantDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const [ovRes, ledgerRes, sellersRes, wdRes, loginRes] = await Promise.all([
    supabaseAdmin.rpc("get_merchant_overview", { p_user_id: id }),
    supabaseAdmin.rpc("get_merchant_ledger", { p_user_id: id, p_type: null, p_limit: 200 }),
    supabaseAdmin.rpc("get_merchant_resellers", { p_user_id: id }),
    supabaseAdmin.rpc("get_merchant_withdrawals", { p_user_id: id }),
    supabaseAdmin
      .from("merchant_panel_logins")
      .select("id, username, is_active, must_change_password, last_login_at, locked_until")
      .eq("user_id", id)
      .maybeSingle(),
  ]);

  let panelLogin: PanelLogin | null = null;
  if (loginRes.data) {
    const { count } = await supabaseAdmin
      .from("merchant_panel_sessions")
      .select("id", { count: "exact", head: true })
      .eq("login_id", loginRes.data.id)
      .is("revoked_at", null)
      .gt("expires_at", new Date().toISOString());
    panelLogin = {
      username: loginRes.data.username,
      is_active: loginRes.data.is_active,
      must_change_password: loginRes.data.must_change_password,
      last_login_at: loginRes.data.last_login_at,
      locked_until: loginRes.data.locked_until,
      live_sessions: count ?? 0,
    };
  }

  const overview = ovRes.data as Overview | null;
  if (ovRes.error) console.error("[merchant-detail]", ovRes.error.message);
  if (!overview || overview.success !== true) notFound();

  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/merchants"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Merchants</span>
      </Link>

      <div>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <Store size={44} className="text-emerald-400" />
          {overview.display_name || overview.username || "Merchant"}
        </h1>
        <p className="text-white/40 mt-2">
          ID {overview.short_id ?? "—"} · {overview.country_code || "—"} ·{" "}
          {overview.commission_percent}% margin
          {overview.contact ? ` · ${overview.contact}` : ""}
        </p>
      </div>

      <MerchantDetailClient
        overview={overview}
        ledger={(ledgerRes.data as LedgerRow[]) ?? []}
        sellers={(sellersRes.data as SellerRow[]) ?? []}
        withdrawals={(wdRes.data as WithdrawalRow[]) ?? []}
        panelLogin={panelLogin}
      />
    </div>
  );
}
