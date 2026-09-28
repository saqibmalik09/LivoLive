import Link from 'next/link';
import { periodLabel } from '@/lib/period';

export function PeriodBanner({
  period,
  hubHref = '/network',
}: {
  period: string;
  hubHref?: string;
}) {
  return (
    <div className="glass-card px-5 py-3 flex flex-wrap items-center justify-between gap-3 border-amber-500/20 bg-amber-500/5">
      <p className="text-xs text-white/60">
        Period{' '}
        <span className="font-mono text-amber-300 font-bold">{period}</span>
        <span className="text-white/40"> · {periodLabel(period)}</span>
      </p>
      <Link href={hubHref} className="text-[10px] font-black uppercase tracking-widest text-amber-400 hover:underline">
        Change in Network
      </Link>
    </div>
  );
}
