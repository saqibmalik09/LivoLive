import Link from "next/link";
import { Calendar } from "lucide-react";
import { periodLabel } from "@/lib/salary-hub/constants";
export function HubPeriodBanner({ period, hubHref }: { period: string; hubHref?: string }) {
  return (
    <div className="flex flex-wrap items-center gap-3 rounded-2xl border border-emerald-500/25 bg-emerald-500/10 px-4 py-3">
      <Calendar size={16} className="text-emerald-400 shrink-0" />
      <div className="min-w-0">
        <p className="text-[10px] font-black uppercase tracking-widest text-emerald-400/70">
          Salary Hub period
        </p>
        <p className="text-sm font-black text-white">
          {periodLabel(period)} <span className="font-mono text-white/40 text-xs">({period})</span>
        </p>
      </div>
      <Link
        href={hubHref || `/salary-hub?period=${period}`}
        className="ml-auto text-[10px] font-black uppercase tracking-widest text-emerald-300 hover:text-white"
      >
        Change period →
      </Link>
    </div>
  );
}
