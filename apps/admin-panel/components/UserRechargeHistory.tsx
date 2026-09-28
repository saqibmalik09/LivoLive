import { Coins, ScrollText } from "lucide-react";
export type RechargeHistoryRow = {
  id: string;
  amount: number;
  transactionType: string;
  currencyType: string;
  description: string | null;
  createdAt: string;
};
const typeLabels: Record<string, string> = {
  recharge: "In-app recharge",
  transfer_in: "From reseller",
  seller_package: "Seller package",
  invite_first_recharge: "Invite first recharge",
  invite_recharge_bonus: "Invite recharge bonus",
};
export function UserRechargeHistory({
  rows,
  totalCoins,
}: {
  rows: RechargeHistoryRow[];
  totalCoins: number;
}) {
  return (
    <div className="glass-card space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h3 className="text-xl font-black flex items-center gap-2">
            <ScrollText className="text-amber-400" size={22} />
            Recharge History
          </h3>
          <p className="text-white/40 text-sm mt-1">
            In-app purchases, reseller transfers, and seller packages
          </p>
        </div>
        <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl px-4 py-3 text-right">
          <p className="text-[9px] font-bold text-amber-400/70 uppercase tracking-[0.2em]">
            Total credited
          </p>
          <p className="font-black text-amber-300 flex items-center justify-end gap-1.5 mt-1">
            <Coins size={16} />
            {totalCoins.toLocaleString()}
          </p>
        </div>
      </div>

      {rows.length === 0 ? (
        <div className="rounded-2xl border border-white/5 bg-white/[0.03] p-10 text-center text-white/30 text-sm">
          No recharge records for this user yet
        </div>
      ) : (
        <div className="space-y-2">
          {rows.map((r) => (
            <div
              key={r.id}
              className="flex flex-wrap items-start justify-between gap-3 rounded-2xl border border-white/5 bg-white/[0.03] px-4 py-3"
            >
              <div className="min-w-0">
                <p className="font-bold text-sm">
                  {typeLabels[r.transactionType] ?? r.transactionType}
                </p>
                <p className="text-xs text-white/40 mt-1 line-clamp-2">{r.description || "—"}</p>
                <p className="text-[10px] text-white/25 mt-1 uppercase tracking-widest">
                  {r.currencyType}
                </p>
              </div>
              <div className="text-right shrink-0">
                <p className="font-black text-emerald-400">+{Number(r.amount).toLocaleString()}</p>
                <p className="text-[11px] text-white/30 mt-1">
                  {new Date(r.createdAt).toLocaleString()}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
