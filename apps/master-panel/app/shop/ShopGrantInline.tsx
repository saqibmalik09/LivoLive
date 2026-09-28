'use client';

import { useState, useTransition } from 'react';
import { Gift, Loader2, Search } from 'lucide-react';
import { toast } from 'sonner';
import { findUserByQuery, grantShopItemToUser } from './actions';

export function ShopGrantInline({
  itemId,
  itemName,
}: {
  itemId: string;
  itemName: string;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState<any[]>([]);
  const [searching, setSearching] = useState(false);
  const [pending, startTransition] = useTransition();

  const search = async () => {
    setSearching(true);
    const res = await findUserByQuery(query);
    setSearching(false);
    if (!res.success) {
      toast.error(res.error);
      return;
    }
    setUsers(res.users || []);
  };

  const grant = (userId: string, username: string) => {
    if (!confirm(`Grant "${itemName}" to @${username}?`)) return;
    startTransition(async () => {
      const res = await grantShopItemToUser(userId, itemId, true);
      if (!res.success) toast.error(res.error || 'Grant failed');
      else {
        toast.success(`Granted to @${username}`);
        setOpen(false);
        setUsers([]);
        setQuery('');
      }
    });
  };

  return (
    <div className="space-y-3">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="w-full py-3 rounded-xl font-black text-[10px] uppercase tracking-widest bg-amber-500/15 text-amber-300 border border-amber-400/20 hover:bg-amber-500 hover:text-black transition flex items-center justify-center gap-2"
      >
        <Gift size={14} />
        {open ? 'Close' : 'Grant to user'}
      </button>

      {open && (
        <div className="rounded-2xl bg-black/40 border border-white/10 p-4 space-y-3">
          <div className="flex gap-2">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Username or short ID"
              className="flex-1 bg-white/5 border border-white/10 rounded-xl px-3 py-2 text-sm outline-none focus:border-amber-500/40"
            />
            <button
              type="button"
              onClick={search}
              disabled={searching}
              className="px-3 py-2 rounded-xl bg-white/10 hover:bg-white/15"
            >
              {searching ? <Loader2 size={16} className="animate-spin" /> : <Search size={16} />}
            </button>
          </div>
          <div className="space-y-2 max-h-48 overflow-y-auto">
            {users.map((u) => (
              <button
                key={u.id}
                type="button"
                disabled={pending}
                onClick={() => grant(u.id, u.username)}
                className="w-full text-left px-3 py-2 rounded-xl bg-white/5 hover:bg-amber-500/10 border border-white/5 text-sm disabled:opacity-50"
              >
                <span className="font-bold">{u.username}</span>
                <span className="text-white/40 text-xs ml-2">UID {u.short_id}</span>
              </button>
            ))}
            {users.length === 0 && (
              <p className="text-xs text-white/30 text-center py-2">Search a user to grant</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
