import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { ArrowLeft, Store } from "lucide-react";
import { MerchantsManagerClient } from "./MerchantsManagerClient";

export const dynamic = "force-dynamic";

export type MerchantRow = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  country_code: string | null;
  display_name: string | null;
  contact: string | null;
  wallet_balance: number | null;
  is_blocked: boolean | null;
  blocked_reason: string | null;
  commission_percent: number | null;
  coins_per_usd: number | null;
  credit_limit: number | null;
  total_sales: number | null;
  total_profit: number | null;
  total_deposited: number | null;
  total_withdrawn: number | null;
  seller_count: number | null;
  pending_withdrawals: number | null;
  merchant_since: string | null;
};

export type PendingWithdrawal = {
  id: string;
  merchant_id: string;
  merchant_name: string | null;
  merchant_sid: number | null;
  amount_coins: number;
  amount_usd: number | null;
  method: string | null;
  account_details: string | null;
  status: string;
  note: string | null;
  requested_at: string;
};

export default async function MerchantsPage() {
  const [listRes, withdrawalRes] = await Promise.all([
    supabaseAdmin.rpc("admin_list_merchants", { p_query: null, p_limit: 300 }),
    supabaseAdmin.rpc("admin_list_merchant_withdrawals", { p_status: "pending", p_limit: 100 }),
  ]);

  if (listRes.error) console.error("[merchants]", listRes.error.message);
  if (withdrawalRes.error) console.error("[merchant-withdrawals]", withdrawalRes.error.message);

  const merchants = (listRes.data as MerchantRow[]) ?? [];
  const pending = (withdrawalRes.data as PendingWithdrawal[]) ?? [];

  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Settings</span>
      </Link>

      <div>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <Store size={48} className="text-emerald-400" />
          Merchants
        </h1>
        <p className="text-white/40 mt-2">
          Wholesale tier above coin sellers — Admin → Merchant → Coin Seller → User.
          Merchants hold their own stock and supply coin sellers by ID.
        </p>
        {listRes.error ? (
          <p className="mt-3 text-xs text-rose-300 font-bold">
            Could not load merchants: {listRes.error.message}
          </p>
        ) : null}
      </div>

      <MerchantsManagerClient merchants={merchants} pendingWithdrawals={pending} />
    </div>
  );
}
