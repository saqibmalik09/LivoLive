"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  Search, Loader2, Send, CheckCircle2, XCircle, User, Store, UserPlus,
} from "lucide-react";
import {
  searchSellersAction, rechargeAction,
  searchUsersAction, rechargeUserAction, openResellerAction,
} from "./actions";

type Target = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  reseller_coins?: number;
  coins?: number;
  is_reseller?: boolean;
  is_merchant?: boolean;
  is_banned?: boolean;
  is_linked?: boolean;
  is_mine?: boolean;
};

type Mode = "seller" | "user" | "open";

const n = (v: number | undefined) => (v ?? 0).toLocaleString();

const MODES: { id: Mode; label: string; icon: typeof Store; hint: string }[] = [
  { id: "seller", label: "Coin seller", icon: Store,
    hint: "Send stock to a coin seller so they can resell it." },
  { id: "user", label: "User ID", icon: User,
    hint: "Send coins straight to a player's balance. They can spend it immediately." },
  { id: "open", label: "Open seller", icon: UserPlus,
    hint: "Turn a normal account into your coin seller." },
];

export function RechargeClient({
  balance, creditLimit, commission, blocked, recent,
}: {
  balance: number;
  creditLimit: number;
  commission: number;
  blocked: boolean;
  recent: Target[];
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();

  const [mode, setMode] = useState<Mode>("seller");
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Target[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [selected, setSelected] = useState<Target | null>(null);
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);

  const spendable = balance + creditLimit;
  const amt = Number(amount.replace(/[^0-9]/g, "")) || 0;
  const profit = Math.floor((amt * commission) / 100);
  const active = MODES.find((m) => m.id === mode)!;

  function switchMode(next: Mode) {
    setMode(next);
    setSelected(null);
    setResults(null);
    setQuery("");
    setAmount("");
    setResult(null);
  }

  async function runSearch() {
    const q = query.trim();
    if (!q) return;
    setSearching(true);
    setResult(null);
    const res = mode === "seller" ? await searchSellersAction(q) : await searchUsersAction(q);
    setSearching(false);
    if ("error" in res && res.error) {
      setResult({ ok: false, text: res.error });
      return;
    }
    setResults(("sellers" in res ? res.sellers : res.users) as Target[]);
  }

  async function send() {
    if (!selected) return;
    if (amt <= 0) {
      setResult({ ok: false, text: "Enter an amount greater than zero" });
      return;
    }
    if (amt > spendable) {
      setResult({ ok: false, text: `You only hold ${n(balance)} coins` });
      return;
    }
    const who = `${selected.username ?? "account"} (ID ${selected.short_id ?? "—"})`;
    if (!confirm(`Send ${n(amt)} coins to ${who}?`)) return;

    setBusy(true);
    const res = mode === "seller"
      ? await rechargeAction(selected.id, amt, note)
      : await rechargeUserAction(selected.id, amt, note);
    setBusy(false);
    setResult({
      ok: res.success,
      text: res.success
        ? `${res.message}${res.profit ? ` · profit ${n(res.profit)} coins` : ""}`
        : res.message,
    });
    if (res.success) {
      setSelected(null); setAmount(""); setNote(""); setResults(null); setQuery("");
      startTransition(() => router.refresh());
    }
  }

  async function openSeller(t: Target) {
    const who = `${t.username ?? "account"} (ID ${t.short_id ?? "—"})`;
    if (!confirm(`Open ${who} as your coin seller?\n\nThey will be able to sell coins on your behalf.`)) {
      return;
    }
    setBusy(true);
    const res = await openResellerAction(t.id);
    setBusy(false);
    setResult({ ok: res.success, text: res.message });
    if (res.success) {
      setResults(null); setQuery("");
      startTransition(() => router.refresh());
    }
  }

  return (
    <div className="space-y-6">
      <section className="glass-card !p-6 space-y-4">
        <div className="flex items-baseline justify-between gap-3 flex-wrap">
          <h1 className="text-lg font-black">Recharge &amp; sellers</h1>
          <p className="text-xs text-white/40">
            Balance <span className="text-amber-300 font-bold">{n(balance)}</span> coins
            {creditLimit > 0 ? ` · credit ${n(creditLimit)}` : ""}
          </p>
        </div>

        {/* mode selector */}
        <div className="flex gap-2 flex-wrap">
          {MODES.map((m) => {
            const Icon = m.icon;
            const on = m.id === mode;
            return (
              <button
                key={m.id}
                onClick={() => switchMode(m.id)}
                className={`inline-flex items-center gap-2 text-[10px] font-black uppercase tracking-widest px-4 py-2.5 rounded-xl transition-colors ${
                  on ? "bg-emerald-500/20 text-emerald-300" : "bg-white/5 text-white/40 hover:text-white/70"
                }`}
              >
                <Icon size={13} /> {m.label}
              </button>
            );
          })}
        </div>
        <p className="text-[11px] text-white/40">{active.hint}</p>

        {blocked ? (
          <p className="text-xs text-rose-300">
            Your account is blocked, so this is disabled.
          </p>
        ) : null}

        <div className="flex gap-2 flex-wrap">
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") runSearch(); }}
            disabled={blocked}
            placeholder={mode === "seller" ? "Coin seller's ID or name" : "User's ID or name"}
            className="flex-1 min-w-[180px] bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40 disabled:opacity-50"
          />
          <button
            onClick={runSearch}
            disabled={searching || blocked}
            className="inline-flex items-center gap-2 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 transition-colors font-black text-xs uppercase tracking-widest px-5 rounded-xl disabled:opacity-50"
          >
            {searching ? <Loader2 size={14} className="animate-spin" /> : <Search size={14} />}
            Find
          </button>
        </div>

        {result ? (
          <p className={`text-xs font-bold flex items-center gap-2 ${result.ok ? "text-emerald-300" : "text-rose-300"}`}>
            {result.ok ? <CheckCircle2 size={14} /> : <XCircle size={14} />}
            {result.text}
          </p>
        ) : null}

        {/* results */}
        {!selected && results ? (
          results.length === 0 ? (
            <p className="text-xs text-white/40 py-3">
              {mode === "seller"
                ? "No coin seller found with that ID or name. Only accounts marked as coin sellers can be topped up here — use “Open seller” to create one."
                : "No account found with that ID or name."}
            </p>
          ) : (
            <div className="space-y-2 pt-1">
              {results.map((t) => (
                <Row
                  key={t.id}
                  t={t}
                  mode={mode}
                  busy={busy}
                  onPick={mode === "open" ? undefined : () => setSelected(t)}
                  onOpen={mode === "open" ? () => openSeller(t) : undefined}
                />
              ))}
            </div>
          )
        ) : null}

        {/* amount */}
        {selected ? (
          <div className="space-y-4 pt-1">
            <Row t={selected} mode={mode} selected />
            <div>
              <label className="text-[9px] font-black uppercase tracking-widest text-white/40">
                Amount in coins
              </label>
              <input
                value={amount}
                onChange={(e) => setAmount(e.target.value.replace(/[^0-9]/g, ""))}
                inputMode="numeric"
                className="mt-2 w-full bg-white/5 rounded-xl px-4 py-3.5 text-lg font-black outline-none focus:ring-2 ring-emerald-400/40"
              />
              {amt > 0 ? (
                <p className="text-[11px] text-white/40 mt-2">
                  Leaves {n(Math.max(0, balance - amt))} coins
                  {commission > 0 ? ` · your profit ${n(profit)} coins` : ""}
                </p>
              ) : null}
            </div>
            <div>
              <label className="text-[9px] font-black uppercase tracking-widest text-white/40">
                Note (optional)
              </label>
              <input
                value={note}
                onChange={(e) => setNote(e.target.value)}
                className="mt-2 w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40"
              />
            </div>
            <div className="flex gap-2">
              <button
                onClick={send}
                disabled={busy || blocked}
                className="flex-1 inline-flex items-center justify-center gap-2 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 transition-colors font-black text-xs uppercase tracking-widest py-3.5 rounded-xl disabled:opacity-50"
              >
                {busy ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
                Send coins
              </button>
              <button
                onClick={() => { setSelected(null); setAmount(""); }}
                className="px-5 bg-white/5 hover:bg-white/10 transition-colors text-white/60 font-black text-xs uppercase tracking-widest rounded-xl"
              >
                Change
              </button>
            </div>
          </div>
        ) : null}
      </section>

      {/* quick pick, only when topping up sellers */}
      {mode === "seller" && !selected && recent.length > 0 ? (
        <section className="space-y-3">
          <h2 className="text-[10px] font-black uppercase tracking-widest text-white/50">
            Sellers you supply
          </h2>
          <div className="space-y-2">
            {recent.map((t) => (
              <Row key={t.id} t={t} mode="seller" onPick={() => setSelected(t)} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}

function Row({
  t, mode, onPick, onOpen, selected, busy,
}: {
  t: Target;
  mode: Mode;
  onPick?: () => void;
  onOpen?: () => void;
  selected?: boolean;
  busy?: boolean;
}) {
  const stock = mode === "seller" ? t.reseller_coins : t.coins;
  const stockLabel = mode === "seller" ? "stock" : "balance";
  const mine = t.is_linked || t.is_mine;

  return (
    <div
      className={`w-full glass-card !p-4 flex items-center gap-3 ${
        selected ? "ring-1 ring-emerald-400/50" : ""
      }`}
    >
      <div className="w-10 h-10 rounded-xl overflow-hidden bg-white/10 shrink-0 flex items-center justify-center">
        {t.avatar_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={t.avatar_url} alt="" className="w-full h-full object-cover" />
        ) : (
          <User size={16} className="text-white/30" />
        )}
      </div>
      <button
        type="button"
        onClick={onPick}
        disabled={!onPick}
        className={`min-w-0 flex-1 text-left ${onPick ? "hover:opacity-80" : "cursor-default"}`}
      >
        <p className="font-bold text-sm truncate">{t.username ?? "Account"}</p>
        <p className="text-[11px] text-white/40">
          ID {t.short_id ?? "—"} · {stockLabel} {n(stock)}
        </p>
      </button>

      <div className="flex items-center gap-2 shrink-0">
        {t.is_banned ? <Tag tone="rose">Banned</Tag> : null}
        {t.is_merchant ? <Tag tone="sky">Merchant</Tag> : null}
        {mode !== "seller" && t.is_reseller ? <Tag tone="amber">Seller</Tag> : null}
        {mine ? <Tag tone="emerald">Yours</Tag> : null}
        {onOpen ? (
          <button
            onClick={onOpen}
            disabled={busy || t.is_banned || t.is_merchant}
            className="inline-flex items-center gap-1.5 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 transition-colors text-[10px] font-black uppercase tracking-widest px-3 py-2 rounded-lg disabled:opacity-40"
          >
            {busy ? <Loader2 size={12} className="animate-spin" /> : <UserPlus size={12} />}
            Open
          </button>
        ) : null}
      </div>
    </div>
  );
}

function Tag({ children, tone }: { children: React.ReactNode; tone: "rose" | "sky" | "amber" | "emerald" }) {
  const tones = {
    rose: "text-rose-400 bg-rose-500/15",
    sky: "text-sky-300 bg-sky-500/15",
    amber: "text-amber-300 bg-amber-500/15",
    emerald: "text-emerald-400 bg-emerald-500/15",
  };
  return (
    <span className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded ${tones[tone]}`}>
      {children}
    </span>
  );
}
