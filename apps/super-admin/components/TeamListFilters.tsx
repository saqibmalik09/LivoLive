'use client';

import { useRouter } from 'next/navigation';
import { useTransition } from 'react';

export function TeamListFilters({ search, role }: { search: string; role: string }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function go(nextSearch: string, nextRole: string) {
    const params = new URLSearchParams();
    if (nextSearch.trim()) params.set('q', nextSearch.trim());
    if (nextRole !== 'all') params.set('role', nextRole);
    const qs = params.toString();
    startTransition(() => {
      router.push(qs ? `/team?${qs}` : '/team');
    });
  }

  return (
    <div className={`glass-card p-4 flex flex-col sm:flex-row gap-3 ${pending ? 'opacity-70' : ''}`}>
      <input
        defaultValue={search}
        key={search}
        placeholder="Search name, ID, code…"
        className="flex-1 rounded-xl bg-black/40 border border-white/10 px-4 py-2.5 text-sm outline-none focus:border-amber-500/40"
        onKeyDown={(e) => {
          if (e.key === 'Enter') go((e.target as HTMLInputElement).value, role);
        }}
      />
      <select
        value={role}
        onChange={(e) => go(search, e.target.value)}
        className="rounded-xl bg-black/40 border border-white/10 px-3 py-2.5 text-sm"
      >
        <option value="all">All roles</option>
        <option value="county_admin">Country Admin</option>
        <option value="bd">BD</option>
        <option value="assistant">Assistant</option>
        <option value="customer_service">Customer Service</option>
      </select>
    </div>
  );
}
