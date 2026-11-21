"use client";
import { CdnImg } from "@/components/CdnImg";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  Loader2, Ban, CheckCircle2, Pencil, Users, Wallet, TrendingUp,
  Coins, ArrowDownLeft, ArrowUpRight, Clock, Trash2, KeyRound, Globe,
} from "lucide-react";
import type { Overview, LedgerRow, SellerRow, WithdrawalRow, PanelLogin } from "./page";
import {
  adjustMerchantCoins, blockMerchant, updateMerchant,
  setMerchant, processMerchantWithdrawal,
  grantMerchantLogin, setMerchantLoginActive, revokeMerchantSessions,
} from "../actions";

const n = (v: number | null | undefined) => (v ?? 0).toLocaleString();

const ENTRY_LABELS: Record<string, string> = {
  admin_deposit: "Admin recharge",
  admin_deduct: "Admin deduction",
  reseller_recharge: "Sold to coin seller",
  withdrawal_hold: "Withdrawal requested",
  withdrawal_paid: "Withdrawal paid",
  withdrawal_refund: "Withdrawal refunded",
  adjustment: "Adjustment",
};

type Tab = "history" | "deposits" | "sellers" | "withdrawals";

export function MerchantDetailClient({
  overview,
  ledger,
  sellers,
  withdrawals,
  panelLogin,
}: {
  overview: Overview;
  ledger: LedgerRow[];
  sellers: SellerRow[];
  withdrawals: WithdrawalRow[];
  panelLogin: PanelLogin | null;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [tab, setTab] = useState<Tab>("history");
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState(false);

  const [form, setForm] = useState({
    displayName: overview.display_name ?? "",
    contact: overview.contact ?? "",
    commissionPercent: String(overview.commission_percent ?? 0),
    coinsPerUsd: String(overview.coins_per_usd ?? 0),
    creditLimit: String(overview.credit_limit ?? 0),
    notes: overview.notes ?? "",
  });

  const deposits = useMemo(
    () => ledger.filter((r) => r.entry_type === "admin_deposit" || r.entry_type === "admin_deduct"),
    [ledger],
  );

  async function run(fn: () => Promise<{ success: boolean; error?: string }>) {
    setBusy(true);
    const res = await fn();
    setBusy(false);
    if (!res.success) alert(res.error);
    else startTransition(() => router.refresh());
    return res.success;
  }

  async function recharge(sign: 1 | -1) {
    const raw = prompt(
      `${sign > 0 ? "Recharge" : "Remove"} coins.\n\nCurrent balance: ${n(
        overview.wallet_balance,
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
    await run(() => adjustMerchantCoins(overview.user_id, sign * amount, note));
  }

  async function toggleBlock() {
    const blocked = overview.is_blocked;
    let reason: string | undefined;
    if (!blocked) {
      const r = prompt("Reason for blocking this merchant?", "");
      if (r === null) return;
      reason = r;
    } else if (!confirm("Unblock this merchant?")) return;
    await run(() => blockMerchant(overview.user_id, !blocked, reason));
  }

  async function revoke() {
    if (overview.wallet_balance > 0) {
      alert(
        `This merchant still holds ${n(
          overview.wallet_balance,
        )} coins. Remove the balance to zero before revoking merchant access.`,
      );
      return;
    }
    if (!confirm("Remove merchant access from this account? History is kept.")) return;
    const ok = await run(() => setMerchant(overview.user_id, false));
    if (ok) router.push("/merchants");
  }

  async function saveEdits() {
    const pct = Number(form.commissionPercent);
    const rate = Number(form.coinsPerUsd);
    const limit = Number(form.creditLimit);
    if (!Number.isFinite(pct) || pct < 0 || pct > 100) {
      alert("Commission must be between 0 and 100");
      return;
    }
    if (!Number.isFinite(rate) || rate <= 0) {
      alert("Coins per USD must be greater than zero");
      return;
    }
    if (!Number.isFinite(limit) || limit < 0) {
      alert("Credit limit cannot be negative");
      return;
    }
    const ok = await run(() =>
      updateMerchant(overview.user_id, {
        displayName: form.displayName.trim() || undefined,
        contact: form.contact.trim() || undefined,
        commissionPercent: pct,
        coinsPerUsd: Math.trunc(rate),
        creditLimit: Math.trunc(limit),
        notes: form.notes.trim() || undefined,
      }),
    );
    if (ok) setEditing(false);
  }

  async function issueLogin() {
    const fromName = (overview.username ?? "merchant")
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, "")
      .slice(0, 24);
    const suggested =
      panelLogin?.username ?? (fromName.length >= 3 ? fromName : `m${overview.short_id ?? ""}`);
    const username = prompt(
      panelLogin
        ? "Username for the merchant web panel (changing it replaces the old one):"
        : "Choose a username for the merchant web panel:",
      suggested,
    );
    if (username === null) return;
    const password = prompt(
      "Temporary password (8-128 characters). Give this to the merchant — they must change it on first sign-in:",
      Math.random().toString(36).slice(2, 12),
    );
    if (password === null) return;

    const ok = await run(() => grantMerchantLogin(overview.user_id, username, password));
    if (ok) {
      alert(
        `Panel login ready.\n\nURL: https://merchant.skliveparty.online\nUsername: ${username
          .trim()
          .toLowerCase()}\nTemporary password: ${password}\n\nThey will be asked to set their own password on first sign-in. Any previous session has been signed out.`,
      );
    }
  }

  async function decideWithdrawal(w: WithdrawalRow, status: "approved" | "rejected" | "paid") {
    const note = prompt(`Note for this ${status} decision (optional)`, "") ?? undefined;
    await run(() => processMerchantWithdrawal(w.id, status, note, overview.user_id));
  }

  return (
    <div className="space-y-8">
      {overview.is_blocked ? (
        <div className="glass-card !p-5 border border-rose-500/30 bg-rose-500/5">
          <p className="font-black text-rose-300 text-sm flex items-center gap-2">
            <Ban size={15} /> Merchant blocked
          </p>
          {overview.blocked_reason ? (
            <p className="text-xs text-white/50 mt-1">{overview.blocked_reason}</p>
          ) : null}
        </div>
      ) : null}

      {/* figures */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Stat label="Wallet balance" value={n(overview.wallet_balance)} sub={`$${overview.balance_usd}`} icon={Wallet} tone="text-white" />
        <Stat label="Total sales" value={n(overview.total_sales)} sub={`$${overview.sales_usd}`} icon={TrendingUp} tone="text-sky-300" />
        <Stat label="Total profit" value={n(overview.total_profit)} sub={`$${overview.profit_usd}`} icon={Coins} tone="text-emerald-300" />
        <Stat label="Coin sellers" value={n(overview.seller_count)} icon={Users} tone="text-amber-300" />
        <Stat label="Deposited" value={n(overview.total_deposited)} icon={ArrowDownLeft} tone="text-violet-300" />
        <Stat label="Deducted" value={n(overview.total_deducted)} icon={ArrowUpRight} tone="text-rose-300" />
        <Stat label="Withdrawn" value={n(overview.total_withdrawn)} icon={ArrowUpRight} tone="text-white/70" />
        <Stat
          label="Pending withdrawal"
          value={n(overview.pending_withdrawal_coins)}
          sub={`${overview.pending_withdrawal_count} request(s)`}
          icon={Clock}
          tone="text-amber-300"
        />
      </div>

      {/* controls */}
      <div className="glass-card !p-6 space-y-5">
        <div className="flex flex-wrap gap-2">
          <Btn onClick={() => recharge(1)} busy={busy} tone="emerald">
            Recharge coins
          </Btn>
          <Btn onClick={() => recharge(-1)} busy={busy} tone="amber">
            Remove coins
          </Btn>
          <Btn onClick={() => setEditing((v) => !v)} busy={false} tone="sky">
            <Pencil size={12} /> {editing ? "Cancel edit" : "Edit merchant"}
          </Btn>
          <Btn onClick={toggleBlock} busy={busy} tone={overview.is_blocked ? "sky" : "rose"}>
            {overview.is_blocked ? (
              <>
                <CheckCircle2 size={12} /> Unblock
              </>
            ) : (
              <>
                <Ban size={12} /> Block
              </>
            )}
          </Btn>
          <Btn onClick={revoke} busy={busy} tone="rose">
            <Trash2 size={12} /> Remove merchant access
          </Btn>
        </div>

        {editing ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
            <Field label="Display name">
              <input
                value={form.displayName}
                onChange={(e) => setForm({ ...form, displayName: e.target.value })}
                className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-sky-400/40"
              />
            </Field>
            <Field label="Contact">
              <input
                value={form.contact}
                onChange={(e) => setForm({ ...form, contact: e.target.value })}
                className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-sky-400/40"
              />
            </Field>
            <Field label="Commission % (profit margin on sales)">
              <input
                value={form.commissionPercent}
                onChange={(e) => setForm({ ...form, commissionPercent: e.target.value })}
                inputMode="decimal"
                className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-sky-400/40"
              />
            </Field>
            <Field label="Coins per USD (for valuation)">
              <input
                value={form.coinsPerUsd}
                onChange={(e) => setForm({ ...form, coinsPerUsd: e.target.value })}
                inputMode="numeric"
                className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-sky-400/40"
              />
            </Field>
            <Field label="Credit limit (0 = strictly prepaid)">
              <input
                value={form.creditLimit}
                onChange={(e) => setForm({ ...form, creditLimit: e.target.value })}
                inputMode="numeric"
                className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-sky-400/40"
              />
            </Field>
            <Field label="Notes">
              <input
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
                className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-sky-400/40"
              />
            </Field>
            <div className="md:col-span-2">
              <Btn onClick={saveEdits} busy={busy} tone="emerald">
                Save changes
              </Btn>
            </div>
          </div>
        ) : null}
      </div>

      {/* web panel access */}
      <div className="glass-card !p-6 space-y-4">
        <h2 className="font-black uppercase tracking-widest text-[11px] text-sky-300 flex items-center gap-2">
          <Globe size={14} /> Merchant web panel
        </h2>

        {panelLogin ? (
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div className="text-xs text-white/60 space-y-1">
              <p>
                Username{" "}
                <span className="font-black text-white">@{panelLogin.username}</span>
                {panelLogin.is_active ? (
                  <span className="ml-2 text-[9px] font-black uppercase tracking-widest text-emerald-400 bg-emerald-500/15 px-2 py-0.5 rounded">
                    Active
                  </span>
                ) : (
                  <span className="ml-2 text-[9px] font-black uppercase tracking-widest text-rose-400 bg-rose-500/15 px-2 py-0.5 rounded">
                    Disabled
                  </span>
                )}
                {panelLogin.must_change_password ? (
                  <span className="ml-2 text-[9px] font-black uppercase tracking-widest text-amber-300 bg-amber-500/15 px-2 py-0.5 rounded">
                    Must set password
                  </span>
                ) : null}
              </p>
              <p className="text-white/40">
                Last sign-in {fmt(panelLogin.last_login_at)} · {panelLogin.live_sessions} live
                session(s)
                {panelLogin.locked_until &&
                new Date(panelLogin.locked_until).getTime() > Date.now()
                  ? ` · locked until ${fmt(panelLogin.locked_until)}`
                  : ""}
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <Btn onClick={issueLogin} busy={busy} tone="sky">
                <KeyRound size={12} /> Reset password
              </Btn>
              <Btn
                onClick={() =>
                  run(() => setMerchantLoginActive(overview.user_id, !panelLogin.is_active))
                }
                busy={busy}
                tone={panelLogin.is_active ? "rose" : "emerald"}
              >
                {panelLogin.is_active ? "Disable access" : "Enable access"}
              </Btn>
              <Btn
                onClick={() => run(() => revokeMerchantSessions(overview.user_id))}
                busy={busy}
                tone="amber"
              >
                Sign out everywhere
              </Btn>
            </div>
          </div>
        ) : (
          <div className="flex flex-wrap items-center justify-between gap-4">
            <p className="text-xs text-white/50 max-w-lg">
              This merchant has no web-panel login yet. Issue one so they can sign in at
              merchant.skliveparty.online and supply coin sellers themselves. They can
              already use the Merchant Panel inside the app.
            </p>
            <Btn onClick={issueLogin} busy={busy} tone="emerald">
              <KeyRound size={12} /> Issue panel login
            </Btn>
          </div>
        )}
      </div>

      {/* tabs */}
      <div className="flex flex-wrap gap-2">
        {(
          [
            ["history", `Transactions (${ledger.length})`],
            ["deposits", `Deposit history (${deposits.length})`],
            ["sellers", `Coin sellers (${sellers.length})`],
            ["withdrawals", `Withdrawals (${withdrawals.length})`],
          ] as [Tab, string][]
        ).map(([id, label]) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            className={`text-[10px] font-black uppercase tracking-widest px-4 py-2.5 rounded-xl transition-colors ${
              tab === id ? "bg-white/15 text-white" : "bg-white/5 text-white/40 hover:text-white/70"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === "history" ? <LedgerTable rows={ledger} /> : null}
      {tab === "deposits" ? <LedgerTable rows={deposits} /> : null}

      {tab === "sellers" ? (
        sellers.length === 0 ? (
          <Empty>This merchant has not supplied any coin seller yet.</Empty>
        ) : (
          <div className="space-y-2">
            {sellers.map((s) => (
              <div
                key={s.id}
                className="glass-card !p-4 flex flex-wrap items-center justify-between gap-4"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-10 h-10 rounded-lg overflow-hidden bg-white/10 shrink-0">
                    {s.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <CdnImg src={s.avatar_url} alt="" className="w-full h-full object-cover" />
                    ) : null}
                  </div>
                  <div className="min-w-0">
                    <p className="font-black text-sm truncate flex items-center gap-2">
                      {s.username ?? "Seller"}
                      {s.is_linked ? (
                        <span className="text-[9px] font-black uppercase tracking-widest text-emerald-400 bg-emerald-500/15 px-2 py-0.5 rounded">
                          Linked
                        </span>
                      ) : null}
                      {s.is_banned ? (
                        <span className="text-[9px] font-black uppercase tracking-widest text-rose-400 bg-rose-500/15 px-2 py-0.5 rounded">
                          Banned
                        </span>
                      ) : null}
                    </p>
                    <p className="text-[11px] text-white/40">
                      ID {s.short_id ?? "—"} · stock {n(s.reseller_coins)}
                    </p>
                  </div>
                </div>
                <div className="flex gap-6 text-right">
                  <div>
                    <p className="text-[9px] font-black uppercase tracking-widest text-white/40">
                      Supplied
                    </p>
                    <p className="text-sm font-black text-sky-300">{n(s.total_supplied)}</p>
                  </div>
                  <div>
                    <p className="text-[9px] font-black uppercase tracking-widest text-white/40">
                      Times
                    </p>
                    <p className="text-sm font-black">{n(s.supply_count)}</p>
                  </div>
                  <div>
                    <p className="text-[9px] font-black uppercase tracking-widest text-white/40">
                      Last
                    </p>
                    <p className="text-sm font-black text-white/60">{fmt(s.last_supplied_at)}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )
      ) : null}

      {tab === "withdrawals" ? (
        withdrawals.length === 0 ? (
          <Empty>No withdrawal requests yet.</Empty>
        ) : (
          <div className="space-y-2">
            {withdrawals.map((w) => (
              <div
                key={w.id}
                className="glass-card !p-4 flex flex-wrap items-center justify-between gap-4"
              >
                <div className="min-w-0">
                  <p className="font-black text-sm">
                    {n(w.amount_coins)} coins
                    {w.amount_usd ? (
                      <span className="text-white/40 font-medium"> · ${w.amount_usd}</span>
                    ) : null}
                  </p>
                  <p className="text-[11px] text-white/40">
                    {fmt(w.requested_at)}
                    {w.method ? ` · ${w.method}` : ""}
                    {w.account_details ? ` · ${w.account_details}` : ""}
                  </p>
                  {w.note ? <p className="text-[11px] text-white/30 italic mt-1">{w.note}</p> : null}
                  {w.admin_note ? (
                    <p className="text-[11px] text-sky-300/60 mt-1">Admin: {w.admin_note}</p>
                  ) : null}
                </div>
                <div className="flex items-center gap-2">
                  <StatusPill status={w.status} />
                  {w.status === "pending" || w.status === "approved" ? (
                    <>
                      <Btn onClick={() => decideWithdrawal(w, "paid")} busy={busy} tone="emerald">
                        Mark paid
                      </Btn>
                      {w.status === "pending" ? (
                        <Btn onClick={() => decideWithdrawal(w, "rejected")} busy={busy} tone="rose">
                          Reject
                        </Btn>
                      ) : null}
                    </>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        )
      ) : null}
    </div>
  );
}

// ── helpers ───────────────────────────────────────────────────────

function fmt(iso: string | null) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString(undefined, {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function LedgerTable({ rows }: { rows: LedgerRow[] }) {
  if (rows.length === 0) return <Empty>No records yet.</Empty>;
  return (
    <div className="glass-card !p-0 overflow-x-auto">
      <table className="w-full text-sm min-w-[720px]">
        <thead>
          <tr className="text-[9px] font-black uppercase tracking-widest text-white/40 border-b border-white/10">
            <th className="text-left p-4">When</th>
            <th className="text-left p-4">Type</th>
            <th className="text-left p-4">Counterparty</th>
            <th className="text-right p-4">Amount</th>
            <th className="text-right p-4">Profit</th>
            <th className="text-right p-4">Balance</th>
            <th className="text-left p-4">By</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} className="border-b border-white/5 last:border-0">
              <td className="p-4 text-white/50 text-xs whitespace-nowrap">{fmt(r.created_at)}</td>
              <td className="p-4 font-bold text-xs">
                {ENTRY_LABELS[r.entry_type] ?? r.entry_type}
                {r.note ? <p className="text-white/30 italic font-medium mt-0.5">{r.note}</p> : null}
              </td>
              <td className="p-4 text-xs text-white/60">
                {r.counterparty_name ? (
                  <>
                    {r.counterparty_name}
                    <span className="text-white/30"> · ID {r.counterparty_sid ?? "—"}</span>
                  </>
                ) : (
                  "—"
                )}
              </td>
              <td
                className={`p-4 text-right font-black whitespace-nowrap ${
                  r.direction > 0 ? "text-emerald-300" : "text-amber-300"
                }`}
              >
                {r.direction > 0 ? "+" : "−"}
                {n(r.amount)}
              </td>
              <td className="p-4 text-right text-emerald-300/80 text-xs">
                {r.profit_coins > 0 ? n(r.profit_coins) : "—"}
              </td>
              <td className="p-4 text-right text-white/40 text-xs">{n(r.balance_after)}</td>
              <td className="p-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                {r.performed_by_role}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
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
    <span className={`text-[9px] font-black uppercase tracking-widest px-2.5 py-1 rounded ${tone}`}>
      {status}
    </span>
  );
}

function Stat({
  label,
  value,
  sub,
  icon: Icon,
  tone,
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

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-[9px] font-black uppercase tracking-widest text-white/40 mb-2">{label}</p>
      {children}
    </div>
  );
}

function Empty({ children }: { children: React.ReactNode }) {
  return <div className="glass-card p-12 text-center text-white/40">{children}</div>;
}

function Btn({
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
      className={`inline-flex items-center gap-1.5 ${tones[tone]} transition-colors text-[10px] font-black uppercase tracking-widest px-4 py-2.5 rounded-xl disabled:opacity-50`}
    >
      {busy ? <Loader2 size={12} className="animate-spin" /> : null}
      {children}
    </button>
  );
}
