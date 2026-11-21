"use client";
import { CdnImg } from "@/components/CdnImg";
import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Loader2, Search, UserPlus, Ban, CheckCircle2, Coins, TrendingUp,
  Wallet, Users, ChevronRight, Clock,
} from "lucide-react";
import type { MerchantRow, PendingWithdrawal } from "./page";
import {
  searchUsersForMerchant, setMerchant, adjustMerchantCoins,
  blockMerchant, processMerchantWithdrawal,
} from "./actions";

type Candidate = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  country_code: string | null;
  is_merchant: boolean | null;
  is_reseller: boolean | null;
  is_banned: boolean | null;
};

const n = (v: number | null | undefined) => (v ?? 0).toLocaleString();

export function MerchantsManagerClient({
  merchants,
  pendingWithdrawals,
}: {
  merchants: MerchantRow[];
  pendingWithdrawals: PendingWithdrawal[];
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();

  const [query, setQuery] = useState("");
  const [candidates, setCandidates] = useState<Candidate[]>([]);
  const [searching, setSearching] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [filter, setFilter] = useState("");

  // ── add merchant ────────────────────────────────────────────────
  async function runSearch() {
    const q = query.trim();
    if (!q) return;
    setSearching(true);
    const res = await searchUsersForMerchant(q);
    setSearching(false);
    if (!res.success) {
      alert(res.error);
      return;
    }
    setCandidates((res.users as Candidate[]) ?? []);
  }

  async function promote(c: Candidate) {
    const commission = prompt(
      `Commission % for ${c.username ?? "user"} (profit margin on coins sold to sellers).\n\nEnter 0 for none.`,
      "5",
    );
    if (commission === null) return;
    const pct = Number(commission);
    if (!Number.isFinite(pct) || pct < 0 || pct > 100) {
      alert("Commission must be between 0 and 100");
      return;
    }
    setBusyId(c.id);
    const res = await setMerchant(c.id, true, { commissionPercent: pct });
    setBusyId(null);
    if (!res.success) alert(res.error);
    else {
      setCandidates((prev) =>
        prev.map((x) => (x.id === c.id ? { ...x, is_merchant: true } : x)),
      );
      startTransition(() => router.refresh());
    }
  }

  // ── row actions ─────────────────────────────────────────────────
  async function recharge(m: MerchantRow, sign: 1 | -1) {
    const label = sign > 0 ? "Recharge" : "Remove";
    const raw = prompt(
      `${label} coins for ${m.username ?? "merchant"} (ID ${m.short_id ?? "—"}).\n\nCurrent balance: ${n(
        m.wallet_balance,
      )} coins.`,
      "",
    );
    if (raw === null) return;
    const amount = Number(raw.replace(/[^0-9]/g, ""));
    if (!Number.isFinite(amount) || amount <= 0) {
      alert("Enter a positive number of coins");
      return;
    }
    const note = prompt("Note for the record (optional)", "") ?? undefined;
    setBusyId(m.id);
    const res = await adjustMerchantCoins(m.id, sign * amount, note);
    setBusyId(null);
    if (!res.success) alert(res.error);
    else startTransition(() => router.refresh());
  }

  async function toggleBlock(m: MerchantRow) {
    const blocked = m.is_blocked === true;
    let reason: string | undefined;
    if (!blocked) {
      const r = prompt(`Reason for blocking ${m.username ?? "merchant"}?`, "");
      if (r === null) return;
      reason = r;
    } else if (!confirm(`Unblock ${m.username ?? "merchant"}?`)) {
      return;
    }
    setBusyId(m.id);
    const res = await blockMerchant(m.id, !blocked, reason);
    setBusyId(null);
    if (!res.success) alert(res.error);
    else startTransition(() => router.refresh());
  }

  async function handleWithdrawal(
    w: PendingWithdrawal,
    status: "approved" | "rejected" | "paid",
  ) {
    const note = prompt(`Note for this ${status} decision (optional)`, "") ?? undefined;
    setBusyId(w.id);
    const res = await processMerchantWithdrawal(w.id, status, note, w.merchant_id);
    setBusyId(null);
    if (!res.success) alert(res.error);
    else startTransition(() => router.refresh());
  }

  const shown = merchants.filter((m) => {
    const f = filter.trim().toLowerCase();
    if (!f) return true;
    return (
      (m.username ?? "").toLowerCase().includes(f) ||
      (m.display_name ?? "").toLowerCase().includes(f) ||
      String(m.short_id ?? "").includes(f)
    );
  });

  const totals = merchants.reduce(
    (a, m) => ({
      balance: a.balance + (m.wallet_balance ?? 0),
      sales: a.sales + (m.total_sales ?? 0),
      profit: a.profit + (m.total_profit ?? 0),
      sellers: a.sellers + (m.seller_count ?? 0),
    }),
    { balance: 0, sales: 0, profit: 0, sellers: 0 },
  );

  return (
    <div className="space-y-8">
      {/* totals */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Stat label="Merchants" value={n(merchants.length)} icon={Store2} />
        <Stat label="Coins held" value={n(totals.balance)} icon={Wallet} />
        <Stat label="Total sales" value={n(totals.sales)} icon={TrendingUp} />
        <Stat label="Total profit" value={n(totals.profit)} icon={Coins} />
      </div>

      {/* pending withdrawals */}
      {pendingWithdrawals.length > 0 ? (
        <div className="glass-card !p-6 space-y-4">
          <h2 className="font-black uppercase tracking-widest text-[11px] text-amber-300 flex items-center gap-2">
            <Clock size={14} /> Pending withdrawals ({pendingWithdrawals.length})
          </h2>
          <div className="space-y-3">
            {pendingWithdrawals.map((w) => (
              <div
                key={w.id}
                className="flex flex-wrap items-center justify-between gap-3 bg-white/5 rounded-xl p-4"
              >
                <div className="min-w-0">
                  <p className="font-black truncate">
                    {w.merchant_name ?? "Merchant"}{" "}
                    <span className="text-white/40 text-xs">ID {w.merchant_sid ?? "—"}</span>
                  </p>
                  <p className="text-xs text-white/40">
                    {n(w.amount_coins)} coins
                    {w.amount_usd ? ` · $${w.amount_usd}` : ""}
                    {w.method ? ` · ${w.method}` : ""}
                    {w.account_details ? ` · ${w.account_details}` : ""}
                  </p>
                  {w.note ? <p className="text-[11px] text-white/30 italic mt-1">{w.note}</p> : null}
                </div>
                <div className="flex items-center gap-2">
                  <SmallBtn
                    onClick={() => handleWithdrawal(w, "paid")}
                    busy={busyId === w.id}
                    tone="emerald"
                  >
                    Mark paid
                  </SmallBtn>
                  <SmallBtn
                    onClick={() => handleWithdrawal(w, "rejected")}
                    busy={busyId === w.id}
                    tone="rose"
                  >
                    Reject
                  </SmallBtn>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {/* add merchant */}
      <div className="glass-card !p-6 space-y-4">
        <h2 className="font-black uppercase tracking-widest text-[11px] text-emerald-300 flex items-center gap-2">
          <UserPlus size={14} /> Make any ID a merchant
        </h2>
        <div className="flex flex-wrap gap-3">
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") runSearch();
            }}
            placeholder="Search by numeric ID or username"
            className="flex-1 min-w-[220px] bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40"
          />
          <button
            onClick={runSearch}
            disabled={searching}
            className="inline-flex items-center gap-2 bg-emerald-500/20 text-emerald-300 font-black text-xs uppercase tracking-widest px-5 rounded-xl hover:bg-emerald-500/30 transition-colors disabled:opacity-50"
          >
            {searching ? <Loader2 size={14} className="animate-spin" /> : <Search size={14} />}
            Search
          </button>
        </div>

        {candidates.length > 0 ? (
          <div className="space-y-2 pt-2">
            {candidates.map((c) => (
              <div
                key={c.id}
                className="flex items-center justify-between gap-4 bg-white/5 rounded-xl p-3"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-10 h-10 rounded-lg overflow-hidden bg-white/10 shrink-0">
                    {c.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <CdnImg src={c.avatar_url} alt="" className="w-full h-full object-cover" />
                    ) : null}
                  </div>
                  <div className="min-w-0">
                    <p className="font-black truncate text-sm">{c.username ?? "User"}</p>
                    <p className="text-[11px] text-white/40">
                      ID {c.short_id ?? "—"} · {c.country_code || "—"}
                      {c.is_reseller ? " · coin seller" : ""}
                      {c.is_banned ? " · banned" : ""}
                    </p>
                  </div>
                </div>
                {c.is_merchant ? (
                  <span className="text-[10px] font-black uppercase tracking-widest text-emerald-400 shrink-0">
                    Already merchant
                  </span>
                ) : (
                  <SmallBtn onClick={() => promote(c)} busy={busyId === c.id} tone="emerald">
                    Make merchant
                  </SmallBtn>
                )}
              </div>
            ))}
          </div>
        ) : null}
      </div>

      {/* merchant list */}
      <div className="space-y-3">
        <div className="flex items-center justify-between gap-4">
          <h2 className="font-black uppercase tracking-widest text-[11px] text-white/50">
            All merchants ({merchants.length})
          </h2>
          <input
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            placeholder="Filter…"
            className="bg-white/5 rounded-xl px-3 py-2 text-xs outline-none focus:ring-2 ring-white/20 w-44"
          />
        </div>

        {shown.length === 0 ? (
          <div className="glass-card p-12 text-center text-white/40">
            {merchants.length === 0
              ? "No merchants yet. Search an ID above to create the first one."
              : "No merchant matches that filter."}
          </div>
        ) : (
          shown.map((m) => (
            <div key={m.id} className="glass-card !p-5 space-y-4">
              <div className="flex flex-wrap items-center gap-4 justify-between">
                <div className="flex items-center gap-4 min-w-0">
                  <div className="w-12 h-12 rounded-xl overflow-hidden bg-white/10 shrink-0">
                    {m.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <CdnImg src={m.avatar_url} alt="" className="w-full h-full object-cover" />
                    ) : null}
                  </div>
                  <div className="min-w-0">
                    <p className="font-black truncate flex items-center gap-2">
                      {m.display_name || m.username || "Merchant"}
                      {m.is_blocked ? (
                        <span className="text-[9px] font-black uppercase tracking-widest text-rose-400 bg-rose-500/15 px-2 py-0.5 rounded">
                          Blocked
                        </span>
                      ) : null}
                    </p>
                    <p className="text-xs text-white/40">
                      ID {m.short_id ?? "—"} · {m.country_code || "—"} ·{" "}
                      {m.commission_percent ?? 0}% margin
                      {m.contact ? ` · ${m.contact}` : ""}
                    </p>
                    {m.is_blocked && m.blocked_reason ? (
                      <p className="text-[11px] text-rose-300/70 italic mt-1">{m.blocked_reason}</p>
                    ) : null}
                  </div>
                </div>

                <div className="flex items-center gap-2 flex-wrap">
                  <SmallBtn onClick={() => recharge(m, 1)} busy={busyId === m.id} tone="emerald">
                    Recharge
                  </SmallBtn>
                  <SmallBtn onClick={() => recharge(m, -1)} busy={busyId === m.id} tone="amber">
                    Remove coins
                  </SmallBtn>
                  <SmallBtn
                    onClick={() => toggleBlock(m)}
                    busy={busyId === m.id}
                    tone={m.is_blocked ? "sky" : "rose"}
                  >
                    {m.is_blocked ? (
                      <>
                        <CheckCircle2 size={12} /> Unblock
                      </>
                    ) : (
                      <>
                        <Ban size={12} /> Block
                      </>
                    )}
                  </SmallBtn>
                  <Link
                    href={`/merchants/${m.id}`}
                    className="inline-flex items-center gap-1 bg-white/10 hover:bg-white/20 transition-colors text-[10px] font-black uppercase tracking-widest px-3 py-2 rounded-lg"
                  >
                    Detail <ChevronRight size={12} />
                  </Link>
                </div>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-5 gap-3 pt-1">
                <Figure label="Wallet" value={n(m.wallet_balance)} tone="text-white" />
                <Figure label="Sales" value={n(m.total_sales)} tone="text-sky-300" />
                <Figure label="Profit" value={n(m.total_profit)} tone="text-emerald-300" />
                <Figure label="Deposited" value={n(m.total_deposited)} tone="text-violet-300" />
                <Figure
                  label="Coin sellers"
                  value={n(m.seller_count)}
                  tone="text-amber-300"
                  icon={Users}
                />
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

// ── small presentational helpers ──────────────────────────────────

function Store2({ size, className }: { size?: number; className?: string }) {
  return <Coins size={size} className={className} />;
}

function Stat({
  label,
  value,
  icon: Icon,
}: {
  label: string;
  value: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
}) {
  return (
    <div className="glass-card !p-5">
      <Icon size={16} className="text-white/40" />
      <p className="text-2xl font-black mt-3">{value}</p>
      <p className="text-[10px] font-black uppercase tracking-widest text-white/40 mt-1">{label}</p>
    </div>
  );
}

function Figure({
  label,
  value,
  tone,
  icon: Icon,
}: {
  label: string;
  value: string;
  tone: string;
  icon?: React.ComponentType<{ size?: number; className?: string }>;
}) {
  return (
    <div className="bg-white/5 rounded-xl p-3">
      <div className="flex items-center gap-1.5">
        {Icon ? <Icon size={11} className="text-white/30" /> : null}
        <p className="text-[9px] font-black uppercase tracking-widest text-white/40">{label}</p>
      </div>
      <p className={`text-sm font-black mt-1 ${tone}`}>{value}</p>
    </div>
  );
}

function SmallBtn({
  children,
  onClick,
  busy,
  tone,
}: {
  children: React.ReactNode;
  onClick: () => void;
  busy?: boolean;
  tone: "emerald" | "rose" | "amber" | "sky";
}) {
  const tones = {
    emerald: "bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30",
    rose: "bg-rose-500/20 text-rose-300 hover:bg-rose-500/30",
    amber: "bg-amber-500/20 text-amber-300 hover:bg-amber-500/30",
    sky: "bg-sky-500/20 text-sky-300 hover:bg-sky-500/30",
  };
  return (
    <button
      onClick={onClick}
      disabled={busy}
      className={`inline-flex items-center gap-1.5 ${tones[tone]} transition-colors text-[10px] font-black uppercase tracking-widest px-3 py-2 rounded-lg disabled:opacity-50`}
    >
      {busy ? <Loader2 size={12} className="animate-spin" /> : null}
      {children}
    </button>
  );
}
