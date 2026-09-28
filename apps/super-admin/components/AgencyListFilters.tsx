'use client';

import { useRouter } from 'next/navigation';
import { useTransition } from 'react';

export function AgencyListFilters({
  search,
  activeOnly,
  sort,
  period,
}: {
  search: string;
  activeOnly: boolean;
  sort: string;
  period: string;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function go(next: { q?: string; active?: boolean; sort?: string }) {
    const params = new URLSearchParams();
    params.set('period', period);
    const q = next.q ?? search;
    if (q.trim()) params.set('q', q.trim());
    if (!(next.active ?? activeOnly)) params.set('active', '0');
    params.set('sort', next.sort ?? sort);
    startTransition(() => {
      router.push(`/agencies?${params.toString()}`);
    });
  }

  return (
    <div className={`glass-card p-4 flex flex-col sm:flex-row gap-3 flex-wrap ${pending ? 'opacity-70' : ''}`}>
      <input
        defaultValue={search}
        key={search}
        placeholder="Search agency, owner, sponsor…"
        className="flex-1 min-w-[180px] rounded-xl bg-black/40 border border-white/10 px-4 py-2.5 text-sm outline-none focus:border-emerald-500/40"
        onKeyDown={(e) => {
          if (e.key === 'Enter') go({ q: (e.target as HTMLInputElement).value });
        }}
      />
      <select
        value={sort}
        onChange={(e) => go({ sort: e.target.value })}
        className="rounded-xl bg-black/40 border border-white/10 px-3 py-2.5 text-sm"
      >
        <option value="name">Sort: Name</option>
        <option value="hosts">Sort: Hosts</option>
      </select>
      <label className="flex items-center gap-2 text-xs text-white/60 px-1 cursor-pointer">
        <input
          type="checkbox"
          checked={activeOnly}
          onChange={(e) => go({ active: e.target.checked })}
        />
        Active only
      </label>
    </div>
  );
}
