import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { ArrowLeft, Banknote } from "lucide-react";
import { WithdrawalsClient } from "./WithdrawalsClient";
export const dynamic = "force-dynamic";
export const revalidate = 0;
export default async function WithdrawalsPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string;
  }>;
}) {
  const sp = await searchParams;
  const { data: withdrawals, error } = await supabaseAdmin
    .from("wallet_withdrawals")
    .select(
      "*, users:user_id(username, short_id, avatar_url), target:target_user_id(username, short_id)",
    )
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) {
    console.error("Withdrawals fetch error:", error.message);
  }
  const { data: policy } = await supabaseAdmin
    .from("coin_seller_policy_settings")
    .select("coins_per_usd")
    .eq("id", 1)
    .maybeSingle();
  const coinsPerUsd = Number(policy?.coins_per_usd) || 88000;
  const rows = (withdrawals as any[]) || [];
  const pendingCount = rows.filter((w) => w.status === "pending").length;
  const resellerApprovedCount = rows.filter((w) => w.status === "reseller_approved").length;
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
      </Link>

      <div>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <Banknote size={48} className="text-violet-400" />
          Withdrawals
        </h1>
        <p className="text-white/40 mt-2">
          Official and agent requests land in Pending. Reseller-approved queue — complete to credit
          reseller stock. Reject refunds held cash. Configure fee/days in{" "}
          <Link href="/settings/wallet" className="text-violet-300 underline">
            Wallet Control
          </Link>
          .
        </p>
        {!error && (
          <p className="text-white/50 mt-2 text-sm font-medium">
            Loaded {rows.length} request(s) · {resellerApprovedCount} reseller approved ·{" "}
            {pendingCount} pending
          </p>
        )}
      </div>

      {error && (
        <div className="rounded-2xl border border-red-500/40 bg-red-500/10 px-5 py-4 text-sm text-red-200">
          Failed to load withdrawals: {error.message}
        </div>
      )}

      <WithdrawalsClient
        withdrawals={rows}
        initialSearch={sp.q?.trim() || ""}
        coinsPerUsd={coinsPerUsd}
      />
    </div>
  );
}
