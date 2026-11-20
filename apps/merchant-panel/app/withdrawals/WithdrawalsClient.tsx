"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Banknote, CheckCircle2, XCircle } from "lucide-react";
import { requestWithdrawalAction } from "./actions";

const n = (v: number) => v.toLocaleString();

export function WithdrawalsClient({
  balance,
  blocked,
}: {
  balance: number;
  blocked: boolean;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("");
  const [details, setDetails] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);

  const amt = Number(amount.replace(/[^0-9]/g, "")) || 0;

  async function submit() {
    if (amt <= 0) {
      setResult({ ok: false, text: "Enter an amount greater than zero" });
      return;
    }
    if (amt > balance) {
      setResult({ ok: false, text: `You only hold ${n(balance)} coins` });
      return;
    }
    if (!confirm(`Request a payout of ${n(amt)} coins? They are held until the admin decides.`)) {
      return;
    }
    setBusy(true);
    const res = await requestWithdrawalAction(amt, method, details, note);
    setBusy(false);
    setResult({ ok: res.success, text: res.message });
    if (res.success) {
      setAmount("");
      setNote("");
      startTransition(() => router.refresh());
    }
  }

  return (
    <section className="glass-card !p-6 space-y-4">
      <div className="flex items-baseline justify-between gap-3 flex-wrap">
        <h1 className="text-lg font-black">Request a payout</h1>
        <p className="text-xs text-white/40">
          Available <span className="text-amber-300 font-bold">{n(balance)}</span> coins
        </p>
      </div>

      {blocked ? (
        <p className="text-xs text-rose-300">
          Your account is blocked, so payouts are disabled.
        </p>
      ) : null}

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Field label="Amount in coins">
          <input
            value={amount}
            onChange={(e) => setAmount(e.target.value.replace(/[^0-9]/g, ""))}
            inputMode="numeric"
            disabled={blocked}
            className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm font-black outline-none focus:ring-2 ring-emerald-400/40 disabled:opacity-50"
          />
        </Field>
        <Field label="Payout method">
          <input
            value={method}
            onChange={(e) => setMethod(e.target.value)}
            placeholder="bank, easypaisa…"
            disabled={blocked}
            className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40 disabled:opacity-50"
          />
        </Field>
        <Field label="Account number / details">
          <input
            value={details}
            onChange={(e) => setDetails(e.target.value)}
            disabled={blocked}
            className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40 disabled:opacity-50"
          />
        </Field>
        <Field label="Note (optional)">
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            disabled={blocked}
            className="w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40 disabled:opacity-50"
          />
        </Field>
      </div>

      {result ? (
        <p
          className={`text-xs font-bold flex items-center gap-2 ${
            result.ok ? "text-emerald-300" : "text-rose-300"
          }`}
        >
          {result.ok ? <CheckCircle2 size={14} /> : <XCircle size={14} />}
          {result.text}
        </p>
      ) : null}

      <button
        onClick={submit}
        disabled={busy || blocked}
        className="w-full sm:w-auto inline-flex items-center justify-center gap-2 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 transition-colors font-black text-xs uppercase tracking-widest px-6 py-3.5 rounded-xl disabled:opacity-50"
      >
        {busy ? <Loader2 size={14} className="animate-spin" /> : <Banknote size={14} />}
        Submit request
      </button>
    </section>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-[9px] font-black uppercase tracking-widest text-white/40 mb-2">
        {label}
      </p>
      {children}
    </div>
  );
}
