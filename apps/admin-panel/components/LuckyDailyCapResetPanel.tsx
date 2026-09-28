"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { resetLuckyDailyCaps } from "@/app/settings/lucky-gifts/actions";
import { Loader2, RotateCcw, AlertTriangle } from "lucide-react";
type Props = {
  luckyWindowStart: string | null;
  luckyProWindowStart: string | null;
  luckyTodayUsed: number;
  luckyProTodayUsed: number;
  luckyDailyCap: number | null;
  luckyProDailyCap: number | null;
};
function formatTs(iso: string | null) {
  if (!iso) return "UTC midnight (default)";
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}
export function LuckyDailyCapResetPanel({
  luckyWindowStart,
  luckyProWindowStart,
  luckyTodayUsed,
  luckyProTodayUsed,
  luckyDailyCap,
  luckyProDailyCap,
}: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<string | null>(null);
  function run(scope: "lucky" | "lucky_pro" | "both") {
    const label =
      scope === "both" ? "Lucky + Lucky Pro" : scope === "lucky_pro" ? "Lucky Pro" : "Lucky";
    if (
      !confirm(
        `Reset ${label} daily bonus caps and gift counters?\n\n` +
          "Today's bonus history stays in logs, but caps start counting from now. Gift streak counters also reset to 0.",
      )
    ) {
      return;
    }
    setMessage(null);
    startTransition(async () => {
      const res = await resetLuckyDailyCaps(scope);
      if (!res.success) {
        setMessage(`Error: ${res.error}`);
        return;
      }
      setMessage(`${label} daily caps + counters reset.`);
      router.refresh();
    });
  }
  return (
    <div className="glass-card p-8 space-y-6 border border-rose-500/20">
      <div className="flex items-start gap-3">
        <div className="w-12 h-12 rounded-2xl bg-rose-500/15 border border-rose-500/30 flex items-center justify-center text-rose-400">
          <RotateCcw size={22} />
        </div>
        <div>
          <h3 className="text-lg font-black tracking-tight uppercase">Daily bonus cap reset</h3>
          <p className="text-xs text-white/45 mt-1 max-w-2xl">
            Daily caps stop new bonuses after the sender/global limit for the UTC day. Reset opens a
            fresh window from now (logs are kept) and clears gift streak counters so the next 2–3
            Lucky gifts can win again.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="rounded-2xl bg-black/30 border border-white/10 p-5 space-y-2">
          <p className="text-[10px] font-black uppercase tracking-widest text-amber-400">Lucky</p>
          <p className="text-sm text-white/80">
            Used in window:{" "}
            <span className="font-mono font-bold">{luckyTodayUsed.toLocaleString()}</span>
            {luckyDailyCap != null ? (
              <span className="text-white/40"> / {luckyDailyCap.toLocaleString()} sender cap</span>
            ) : null}
          </p>
          <p className="text-[11px] text-white/35">Window start: {formatTs(luckyWindowStart)}</p>
        </div>
        <div className="rounded-2xl bg-black/30 border border-white/10 p-5 space-y-2">
          <p className="text-[10px] font-black uppercase tracking-widest text-violet-400">
            Lucky Pro
          </p>
          <p className="text-sm text-white/80">
            Used in window:{" "}
            <span className="font-mono font-bold">{luckyProTodayUsed.toLocaleString()}</span>
            {luckyProDailyCap != null ? (
              <span className="text-white/40">
                {" "}
                / {luckyProDailyCap.toLocaleString()} sender cap
              </span>
            ) : null}
          </p>
          <p className="text-[11px] text-white/35">Window start: {formatTs(luckyProWindowStart)}</p>
        </div>
      </div>

      <div className="flex items-start gap-2 text-[11px] text-amber-200/70 bg-amber-500/10 border border-amber-500/20 rounded-xl px-4 py-3">
        <AlertTriangle size={14} className="mt-0.5 shrink-0" />
        <span>
          This does not delete bonus history or refund coins. It only restarts cap counting + gift
          counters for testing / ops.
        </span>
      </div>

      <div className="flex flex-wrap gap-3">
        <button
          type="button"
          disabled={pending}
          onClick={() => run("lucky")}
          className="px-5 py-3 rounded-xl bg-amber-500 hover:bg-amber-400 text-black text-xs font-black uppercase tracking-wider disabled:opacity-50 inline-flex items-center gap-2"
        >
          {pending ? <Loader2 size={14} className="animate-spin" /> : <RotateCcw size={14} />}
          Reset Lucky
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => run("lucky_pro")}
          className="px-5 py-3 rounded-xl bg-violet-500 hover:bg-violet-400 text-white text-xs font-black uppercase tracking-wider disabled:opacity-50 inline-flex items-center gap-2"
        >
          {pending ? <Loader2 size={14} className="animate-spin" /> : <RotateCcw size={14} />}
          Reset Lucky Pro
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => run("both")}
          className="px-5 py-3 rounded-xl bg-rose-500 hover:bg-rose-400 text-white text-xs font-black uppercase tracking-wider disabled:opacity-50 inline-flex items-center gap-2"
        >
          {pending ? <Loader2 size={14} className="animate-spin" /> : <RotateCcw size={14} />}
          Reset both
        </button>
      </div>

      {message ? <p className="text-xs font-medium text-white/70">{message}</p> : null}
    </div>
  );
}
