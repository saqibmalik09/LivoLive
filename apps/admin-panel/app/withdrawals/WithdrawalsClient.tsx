"use client";
import { useState } from "react";
import { Check, Loader2, X, BadgeCheck } from "lucide-react";
import { useRouter } from "next/navigation";
import { processWithdrawal } from "./actions";
type WithdrawalRow = {
  id: string;
  amount: number;
  fee: number;
  net_amount: number;
  target_type: string;
  status: string;
  admin_note: string | null;
  reseller_note?: string | null;
  reseller_processed_at?: string | null;
  created_at: string;
  payment_method: Record<string, unknown> | null;
  users?: {
    username?: string;
    short_id?: number;
    avatar_url?: string;
  } | null;
  target?: {
    username?: string;
    short_id?: number;
  } | null;
};
function statusBadgeClass(status: string) {
  switch (status) {
    case "pending":
      return "bg-amber-500/20 text-amber-300";
    case "reseller_approved":
      return "bg-violet-500/20 text-violet-300";
    case "approved":
      return "bg-sky-500/20 text-sky-300";
    case "completed":
      return "bg-emerald-500/20 text-emerald-300";
    case "rejected":
      return "bg-red-500/20 text-red-300";
    default:
      return "bg-white/10 text-white/40";
  }
}
function statusLabel(status: string) {
  if (status === "reseller_approved") return "Reseller approved";
  return status;
}
export function WithdrawalsClient({
  withdrawals,
  initialSearch = "",
  coinsPerUsd = 88000,
}: {
  withdrawals: WithdrawalRow[];
  initialSearch?: string;
  coinsPerUsd?: number;
}) {
  const router = useRouter();
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [filter, setFilter] = useState<string>("pending");
  const [search, setSearch] = useState(initialSearch);
  const filtered = withdrawals.filter((w) => {
    if (filter !== "all" && w.status !== filter) return false;
    const q = search.trim().toLowerCase();
    if (!q) return true;
    const uid = String(w.users?.short_id ?? "");
    const name = String(w.users?.username ?? "").toLowerCase();
    const targetUid = String(w.target?.short_id ?? "");
    const targetName = String(w.target?.username ?? "").toLowerCase();
    const id = w.id.toLowerCase();
    return (
      uid.includes(q) ||
      name.includes(q) ||
      targetUid.includes(q) ||
      targetName.includes(q) ||
      id.includes(q)
    );
  });
  function stockPreview(w: WithdrawalRow) {
    if (w.target_type !== "reseller") return null;
    const net = Number(w.net_amount) || 0;
    return Math.floor(net * coinsPerUsd);
  }
  async function handle(id: string, action: "approve" | "reject" | "complete") {
    const note =
      action === "reject" ? (window.prompt("Rejection note (optional):") ?? undefined) : undefined;
    if (action === "reject" && note === null) return;
    if (!confirm(`${action.toUpperCase()} withdrawal ${id.slice(0, 8)}…?`)) {
      return;
    }
    setLoadingId(id);
    const res = await processWithdrawal(id, action, note);
    if (!res.success) alert(res.error);
    else router.refresh();
    setLoadingId(null);
  }
  const tabs = [
    "reseller_approved",
    "pending",
    "approved",
    "completed",
    "rejected",
    "cancelled",
    "all",
  ];
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-2">
        {tabs.map((t) => (
          <button
            key={t}
            onClick={() => setFilter(t)}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest ${
              filter === t
                ? "bg-purple-500 text-black"
                : "bg-white/5 text-white/50 hover:text-white"
            }`}
          >
            {t === "reseller_approved" ? "Reseller approved" : t}
          </button>
        ))}
      </div>

      <input
        type="search"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search UID / username / request id…"
        className="w-full max-w-md bg-black/40 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white placeholder:text-white/30"
      />

      {filtered.length === 0 ? (
        <div className="glass rounded-3xl p-12 text-center text-white/40 font-medium">
          No withdrawals in this filter
        </div>
      ) : (
        <div className="space-y-4">
          {filtered.map((w) => {
            const pm = w.payment_method || {};
            const busy = loadingId === w.id;
            const stock = stockPreview(w);
            return (
              <div key={w.id} className="glass rounded-3xl p-6 border border-white/5 space-y-4">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="text-2xl font-black tracking-tight">
                      ${Number(w.amount).toFixed(2)}
                      <span className="text-sm font-bold text-white/40 ml-2">
                        fee ${Number(w.fee).toFixed(2)} · net ${Number(w.net_amount).toFixed(2)}
                      </span>
                    </p>
                    <p className="text-white/50 text-sm mt-1">
                      {w.users?.username || "User"} · ID {w.users?.short_id ?? "—"}
                      {" → "}
                      {w.target_type === "official"
                        ? "Official"
                        : w.target_type === "reseller"
                          ? "Reseller"
                          : w.target_type === "agent"
                            ? "Agent"
                            : w.target_type}{" "}
                      {w.target_type !== "official"
                        ? `${w.target?.username || ""}${
                            w.target?.short_id != null ? ` (${w.target.short_id})` : ""
                          }`
                        : ""}
                    </p>
                    <p className="text-[11px] text-white/30 mt-1 font-mono">
                      {new Date(w.created_at).toLocaleString()} · {w.id}
                    </p>
                    {w.status === "reseller_approved" && w.reseller_processed_at ? (
                      <p className="text-xs text-violet-300/80 mt-2">
                        Approved by reseller {w.target?.username || "reseller"} at{" "}
                        {new Date(w.reseller_processed_at).toLocaleString()}
                        {w.reseller_note ? ` · “${w.reseller_note}”` : ""}
                      </p>
                    ) : null}
                    {stock != null ? (
                      <p className="text-xs text-emerald-300/80 mt-1">
                        Stock credit preview: {stock.toLocaleString()} reseller coins (net ×{" "}
                        {coinsPerUsd.toLocaleString()})
                      </p>
                    ) : null}
                  </div>
                  <span
                    className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest ${statusBadgeClass(w.status)}`}
                  >
                    {statusLabel(w.status)}
                  </span>
                </div>

                <div className="text-sm text-white/60">
                  <span className="font-bold text-white/80">{String(pm.method || "—")}</span>
                  {" · "}
                  {String(pm.name || "")}
                  {" · "}
                  {String(pm.address || "")}
                </div>

                {w.admin_note ? (
                  <p className="text-xs text-white/40">Note: {w.admin_note}</p>
                ) : null}

                <div className="flex flex-wrap gap-2">
                  {w.status === "pending" && (
                    <>
                      <button
                        disabled={busy}
                        onClick={() => handle(w.id, "approve")}
                        className="px-4 py-2 rounded-xl bg-sky-500 text-black text-xs font-black flex items-center gap-2"
                      >
                        {busy ? (
                          <Loader2 size={14} className="animate-spin" />
                        ) : (
                          <Check size={14} />
                        )}
                        Approve
                      </button>
                      <button
                        disabled={busy}
                        onClick={() => handle(w.id, "reject")}
                        className="px-4 py-2 rounded-xl bg-red-500/80 text-white text-xs font-black flex items-center gap-2"
                      >
                        {busy ? <Loader2 size={14} className="animate-spin" /> : <X size={14} />}
                        Reject
                      </button>
                    </>
                  )}
                  {(w.status === "pending" ||
                    w.status === "approved" ||
                    w.status === "reseller_approved") && (
                    <button
                      disabled={busy}
                      onClick={() => handle(w.id, "complete")}
                      className="px-4 py-2 rounded-xl bg-emerald-500 text-black text-xs font-black flex items-center gap-2"
                    >
                      {busy ? (
                        <Loader2 size={14} className="animate-spin" />
                      ) : (
                        <BadgeCheck size={14} />
                      )}
                      {w.target_type === "reseller" ? "Complete & credit stock" : "Complete"}
                    </button>
                  )}
                  {(w.status === "approved" || w.status === "reseller_approved") && (
                    <button
                      disabled={busy}
                      onClick={() => handle(w.id, "reject")}
                      className="px-4 py-2 rounded-xl bg-red-500/80 text-white text-xs font-black flex items-center gap-2"
                    >
                      Reject / Refund
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
