import { redirect } from "next/navigation";
import { getMerchantActor } from "@/lib/merchant-session";
import { getOverview, getWithdrawals, fmtCoins, fmtDate } from "@/lib/merchant-data";
import { Shell, Empty } from "@/components/Shell";
import { WithdrawalsClient } from "./WithdrawalsClient";

export const dynamic = "force-dynamic";

export default async function WithdrawalsPage() {
  const actor = await getMerchantActor();
  if (!actor) redirect("/login");
  if (actor.mustChangePassword) redirect("/change-password");

  const [o, rows] = await Promise.all([
    getOverview(actor.userId),
    getWithdrawals(actor.userId),
  ]);
  if (!o) {
    return (
      <Shell username={actor.username}>
        <Empty>Your merchant account could not be loaded.</Empty>
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
      <WithdrawalsClient balance={o.wallet_balance} blocked={o.is_blocked} />

      <section className="space-y-3">
        <h2 className="text-[10px] font-black uppercase tracking-widest text-white/50">
          Your requests
        </h2>
        {rows.length === 0 ? (
          <Empty>No payout requests yet.</Empty>
        ) : (
          <div className="space-y-2">
            {rows.map((w) => (
              <div key={w.id} className="glass-card !p-4 flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <p className="font-bold text-sm">
                    {fmtCoins(w.amount_coins)} coins
                    {w.amount_usd ? (
                      <span className="text-white/40 font-medium"> · ${w.amount_usd}</span>
                    ) : null}
                  </p>
                  <p className="text-[11px] text-white/40 mt-0.5">
                    {fmtDate(w.requested_at)}
                    {w.method ? ` · ${w.method}` : ""}
                    {w.account_details ? ` · ${w.account_details}` : ""}
                  </p>
                  {w.note ? (
                    <p className="text-[11px] text-white/30 italic mt-0.5">{w.note}</p>
                  ) : null}
                  {w.admin_note ? (
                    <p className="text-[11px] text-sky-300/70 mt-0.5">Admin: {w.admin_note}</p>
                  ) : null}
                </div>
                <StatusPill status={w.status} />
              </div>
            ))}
          </div>
        )}
      </section>
    </Shell>
  );
}

function StatusPill({ status }: { status: string }) {
  const tone =
    status === "paid"
      ? "text-emerald-300 bg-emerald-500/15"
      : status === "approved"
        ? "text-sky-300 bg-sky-500/15"
        : status === "rejected"
          ? "text-rose-300 bg-rose-500/15"
          : "text-amber-300 bg-amber-500/15";
  return (
    <span
      className={`text-[9px] font-black uppercase tracking-widest px-2.5 py-1 rounded shrink-0 ${tone}`}
    >
      {status}
    </span>
  );
}
