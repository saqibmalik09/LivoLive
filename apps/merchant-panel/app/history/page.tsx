import { redirect } from "next/navigation";
import Link from "next/link";
import { getMerchantActor } from "@/lib/merchant-session";
import { getOverview, getLedger, fmtCoins, fmtDate, ENTRY_LABELS } from "@/lib/merchant-data";
import { Shell, Empty } from "@/components/Shell";

export const dynamic = "force-dynamic";

const FILTERS: { label: string; value: string | null }[] = [
  { label: "All", value: null },
  { label: "Recharges to me", value: "deposits" },
  { label: "My sales", value: "sales" },
  { label: "Payouts", value: "withdrawals" },
];

export default async function HistoryPage({
  searchParams,
}: {
  searchParams: Promise<{ filter?: string }>;
}) {
  const actor = await getMerchantActor();
  if (!actor) redirect("/login");
  if (actor.mustChangePassword) redirect("/change-password");

  const sp = await searchParams;
  const active = FILTERS.find((f) => f.value === sp.filter)?.value ?? null;

  const [o, rows] = await Promise.all([
    getOverview(actor.userId),
    getLedger(actor.userId, active, 150),
  ]);

  return (
    <Shell
      username={actor.username}
      displayName={o?.display_name}
      shortId={o?.short_id}
      blocked={o?.is_blocked}
      blockedReason={o?.blocked_reason}
    >
      <h1 className="text-lg font-black">Transaction history</h1>

      <div className="flex gap-2 flex-wrap">
        {FILTERS.map((f) => {
          const isOn = f.value === active;
          return (
            <Link
              key={f.label}
              href={f.value ? `/history?filter=${f.value}` : "/history"}
              className={`text-[10px] font-black uppercase tracking-widest px-4 py-2.5 rounded-xl transition-colors ${
                isOn
                  ? "bg-emerald-500/20 text-emerald-300"
                  : "bg-white/5 text-white/40 hover:text-white/70"
              }`}
            >
              {f.label}
            </Link>
          );
        })}
      </div>

      {rows.length === 0 ? (
        <Empty>No records for this filter yet.</Empty>
      ) : (
        <div className="space-y-2">
          {rows.map((r) => (
            <div key={r.id} className="glass-card !p-4 flex items-start justify-between gap-4">
              <div className="min-w-0">
                <p className="font-bold text-sm">
                  {ENTRY_LABELS[r.entry_type] ?? r.entry_type}
                </p>
                <p className="text-[11px] text-white/40 mt-0.5">
                  {r.counterparty_name
                    ? `${r.counterparty_name} · ID ${r.counterparty_sid ?? "—"} · `
                    : ""}
                  {fmtDate(r.created_at)}
                </p>
                {r.note ? (
                  <p className="text-[11px] text-white/30 italic mt-0.5">{r.note}</p>
                ) : null}
              </div>
              <div className="text-right shrink-0">
                <p
                  className={`font-black text-sm ${
                    r.direction > 0 ? "text-emerald-300" : "text-amber-300"
                  }`}
                >
                  {r.direction > 0 ? "+" : "−"}
                  {fmtCoins(r.amount)}
                </p>
                {r.profit_coins > 0 ? (
                  <p className="text-[10px] text-emerald-300/70">
                    profit {fmtCoins(r.profit_coins)}
                  </p>
                ) : null}
                <p className="text-[10px] text-white/25">
                  bal {fmtCoins(r.balance_after)}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}
    </Shell>
  );
}
