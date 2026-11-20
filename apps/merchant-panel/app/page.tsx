import { redirect } from "next/navigation";
import Link from "next/link";
import {
  Wallet, TrendingUp, Coins, Users, ArrowDownLeft, ArrowUpRight, Clock, Send,
} from "lucide-react";
import { getMerchantActor } from "@/lib/merchant-session";
import { getOverview, getLedger, fmtCoins, fmtDate, ENTRY_LABELS } from "@/lib/merchant-data";
import { Shell, Empty } from "@/components/Shell";

export const dynamic = "force-dynamic";

export default async function OverviewPage() {
  const actor = await getMerchantActor();
  if (!actor) redirect("/login");
  if (actor.mustChangePassword) redirect("/change-password");

  const [o, recent] = await Promise.all([
    getOverview(actor.userId),
    getLedger(actor.userId, null, 8),
  ]);

  if (!o) {
    return (
      <Shell username={actor.username}>
        <Empty>
          Your merchant account could not be loaded. Please contact the admin.
        </Empty>
      </Shell>
    );
  }

  return (
    <Shell
      username={actor.username}
      displayName={o.display_name}
      shortId={o.short_id}
      blocked={o.is_blocked}
      blockedReason={o.blocked_reason}
    >
      {/* wallet */}
      <section className="glass-card !p-7">
        <p className="text-[10px] font-black uppercase tracking-[0.18em] text-white/40">
          Wallet balance
        </p>
        <div className="flex items-end gap-3 mt-3 flex-wrap">
          <p className="text-4xl font-black leading-none">{fmtCoins(o.wallet_balance)}</p>
          <p className="text-white/40 text-sm pb-0.5">coins</p>
          {o.coins_per_usd > 0 ? (
            <p className="text-white/30 text-xs pb-1">≈ ${o.balance_usd}</p>
          ) : null}
        </div>
        {o.credit_limit > 0 ? (
          <p className="text-[11px] text-white/30 mt-2">
            Credit limit {fmtCoins(o.credit_limit)} coins
          </p>
        ) : null}
        <div className="flex gap-2 mt-6 flex-wrap">
          <Link
            href="/recharge"
            className="inline-flex items-center gap-2 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 transition-colors text-[10px] font-black uppercase tracking-widest px-5 py-3 rounded-xl"
          >
            <Send size={13} /> Recharge a coin seller
          </Link>
          <Link
            href="/withdrawals"
            className="inline-flex items-center gap-2 bg-white/5 hover:bg-white/10 transition-colors text-[10px] font-black uppercase tracking-widest px-5 py-3 rounded-xl text-white/70"
          >
            Request payout
          </Link>
        </div>
      </section>

      {/* figures */}
      <section className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Stat label="Total sales" value={fmtCoins(o.total_sales)}
          sub={o.coins_per_usd > 0 ? `$${o.sales_usd}` : undefined}
          icon={TrendingUp} tone="text-sky-300" />
        <Stat label="Total profit" value={fmtCoins(o.total_profit)}
          sub={`${o.commission_percent}% margin`} icon={Coins} tone="text-emerald-300" />
        <Stat label="Coin sellers" value={fmtCoins(o.seller_count)} icon={Users} tone="text-amber-300" />
        <Stat label="Recharged to you" value={fmtCoins(o.total_deposited)} icon={ArrowDownLeft} tone="text-violet-300" />
        <Stat label="Removed by admin" value={fmtCoins(o.total_deducted)} icon={ArrowUpRight} tone="text-rose-300" />
        <Stat label="Paid out" value={fmtCoins(o.total_withdrawn)} icon={Wallet} tone="text-white/70" />
        <Stat label="Payout pending" value={fmtCoins(o.pending_withdrawal_coins)}
          sub={`${o.pending_withdrawal_count} request(s)`} icon={Clock} tone="text-amber-300" />
        <Stat label="Your rate" value={o.coins_per_usd > 0 ? fmtCoins(o.coins_per_usd) : "—"}
          sub="coins per $1" icon={Coins} tone="text-white/70" />
      </section>

      {/* recent activity */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="text-[10px] font-black uppercase tracking-widest text-white/50">
            Recent activity
          </h2>
          <Link href="/history" className="text-[10px] font-black uppercase tracking-widest text-emerald-300/80 hover:text-emerald-300">
            See all
          </Link>
        </div>
        {recent.length === 0 ? (
          <Empty>Nothing yet. Your admin recharges and your sales will show here.</Empty>
        ) : (
          <div className="space-y-2">
            {recent.map((r) => (
              <div key={r.id} className="glass-card !p-4 flex items-center justify-between gap-4">
                <div className="min-w-0">
                  <p className="font-bold text-sm">
                    {ENTRY_LABELS[r.entry_type] ?? r.entry_type}
                  </p>
                  <p className="text-[11px] text-white/40">
                    {r.counterparty_name
                      ? `${r.counterparty_name} · ID ${r.counterparty_sid ?? "—"} · `
                      : ""}
                    {fmtDate(r.created_at)}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  <p className={`font-black text-sm ${r.direction > 0 ? "text-emerald-300" : "text-amber-300"}`}>
                    {r.direction > 0 ? "+" : "−"}{fmtCoins(r.amount)}
                  </p>
                  {r.profit_coins > 0 ? (
                    <p className="text-[10px] text-emerald-300/70">profit {fmtCoins(r.profit_coins)}</p>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </Shell>
  );
}

function Stat({
  label, value, sub, icon: Icon, tone,
}: {
  label: string;
  value: string;
  sub?: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
  tone: string;
}) {
  return (
    <div className="glass-card !p-5">
      <Icon size={15} className="text-white/30" />
      <p className={`text-xl font-black mt-3 ${tone}`}>{value}</p>
      {sub ? <p className="text-[10px] text-white/30 mt-0.5">{sub}</p> : null}
      <p className="text-[9px] font-black uppercase tracking-widest text-white/40 mt-1">{label}</p>
    </div>
  );
}
