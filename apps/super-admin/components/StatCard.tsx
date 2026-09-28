import { cn } from '@/lib/utils';
import type { LucideIcon } from 'lucide-react';

type StatCardProps = {
  label: string;
  value: string | number;
  icon: LucideIcon;
  accent?: string;
};

export function StatCard({ label, value, icon: Icon, accent = 'text-amber-400' }: StatCardProps) {
  return (
    <div className="glass-card p-5 md:p-6">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[10px] font-black uppercase tracking-widest text-white/40">{label}</p>
          <p className="text-2xl md:text-3xl font-black mt-2 tabular-nums">{value}</p>
        </div>
        <div className={cn('w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center', accent)}>
          <Icon size={20} />
        </div>
      </div>
    </div>
  );
}
