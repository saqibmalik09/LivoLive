'use client';

import { useState, useTransition } from 'react';
import {
  removeUserVip,
  searchUsersForBan,
  setSubtreeUserBanned,
  setUserVipLevelForUser,
} from '@/lib/actions';
import type { SearchUser } from '@/lib/types';
import { getPortalPermissions } from '@/lib/permissions';

export default function ModerationPage() {
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState<SearchUser[]>([]);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [vipLevelByUserId, setVipLevelByUserId] = useState<Record<string, number>>({});

  const canGrantVip = getPortalPermissions('super_bd').canGrantVip;

  function onSearch() {
    start(async () => {
      const res = await searchUsersForBan(query);
      if (!res.success) {
        setMessage(res.error);
        setUsers([]);
        return;
      }
      setUsers(res.users);
      setMessage(res.users.length ? null : 'No users found');
    });
  }

  function onBan(id: string, banned: boolean) {
    start(async () => {
      let note: string | null = null;
      if (banned) {
        const raw = window.prompt('Ban note (optional — shown to user in app):', '');
        if (raw === null) return; // cancelled
        note = raw.trim() || null;
      } else if (!window.confirm('Unblock this user? Account + device bans will be cleared.')) {
        return;
      }
      const res = await setSubtreeUserBanned(id, banned, note);
      if (!res.success) {
        setMessage(res.error || 'Failed');
        return;
      }
      setMessage(banned ? 'User blocked' : 'User unblocked');
      setUsers((prev) =>
        prev.map((u) =>
          u.id === id
            ? {
                ...u,
                is_banned: banned,
                ban_reason: banned ? note : null,
              }
            : u,
        ),
      );
    });
  }

  function onVip(id: string) {
    if (!canGrantVip) return;

    start(async () => {
      const selected = vipLevelByUserId[id] ?? 1;
      const ok =
        selected === 0
          ? window.confirm('Remove VIP from this user? This will clear VIP assets/visibility.')
          : window.confirm(
              `Give VIP level ${selected} for 30 days? If VIP is already active, expiry will extend by +30 days.`,
            );
      if (!ok) return;

      const res =
        selected === 0
          ? await removeUserVip(id)
          : await setUserVipLevelForUser(id, selected);
      if (!res.success) {
        setMessage(res.error || 'Failed');
        return;
      }

      setMessage(selected === 0 ? 'VIP removed' : `VIP level ${selected} granted`);
    });
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-black tracking-tight">Moderation</h1>
        <p className="text-white/50 mt-2 text-sm max-w-xl">
          Super Admin can block / unblock any user. Unblock also clears linked device bans so they
          can open the app again.
        </p>
      </div>

      <div className="flex gap-2">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') onSearch();
          }}
          placeholder="Search username or ID"
          className="flex-1 rounded-xl bg-white/5 border border-white/10 px-4 py-3"
        />
        <button
          type="button"
          onClick={onSearch}
          disabled={pending}
          className="rounded-xl bg-amber-500/90 px-5 py-3 font-bold text-black"
        >
          Search
        </button>
      </div>

      {message && <p className="text-sm text-amber-300">{message}</p>}

      <ul className="space-y-3">
        {users.map((u) => (
          <li
            key={u.id}
            className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3"
          >
            <div>
              <div className="flex items-center gap-2">
                <p className="font-bold">{u.username}</p>
                <span
                  className={`rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide ${
                    u.is_banned
                      ? 'bg-red-500/20 text-red-300'
                      : 'bg-emerald-500/15 text-emerald-300'
                  }`}
                >
                  {u.is_banned ? 'Blocked' : 'Active'}
                </span>
              </div>
              <p className="text-xs text-white/40">ID {u.short_id}</p>
              {u.is_banned && u.ban_reason ? (
                <p className="mt-1 text-xs text-white/45">Reason: {u.ban_reason}</p>
              ) : null}
            </div>
            <div className="flex flex-col items-end gap-2">
              {canGrantVip && (
                <div className="flex items-center gap-2">
                  <select
                    value={vipLevelByUserId[u.id] ?? 1}
                    onChange={(e) =>
                      setVipLevelByUserId((prev) => ({
                        ...prev,
                        [u.id]: Number(e.target.value),
                      }))
                    }
                    disabled={pending}
                    className="rounded-lg bg-white/5 border border-white/10 px-3 py-2 text-xs font-bold text-white disabled:opacity-40"
                    aria-label={`VIP level for ${u.username}`}
                  >
                    <option value={0}>VIP 0 (Remove)</option>
                    <option value={1}>VIP 1</option>
                    <option value={2}>VIP 2</option>
                    <option value={3}>VIP 3</option>
                    <option value={4}>VIP 4</option>
                  </select>
                  <button
                    type="button"
                    disabled={pending}
                    onClick={() => onVip(u.id)}
                    className="rounded-lg bg-amber-500/90 text-black px-3 py-2 text-xs font-bold disabled:opacity-40"
                  >
                    {vipLevelByUserId[u.id] === 0 ? 'Remove' : 'Apply'}
                  </button>
                </div>
              )}

              <div className="flex gap-2">
                <button
                  type="button"
                  disabled={pending || u.is_banned === true}
                  onClick={() => onBan(u.id, true)}
                  className="rounded-lg bg-red-500/20 text-red-300 px-3 py-1.5 text-xs font-bold disabled:opacity-40"
                >
                  Block
                </button>
                <button
                  type="button"
                  disabled={pending || u.is_banned !== true}
                  onClick={() => onBan(u.id, false)}
                  className="rounded-lg bg-emerald-500/20 text-emerald-300 px-3 py-1.5 text-xs font-bold disabled:opacity-40"
                >
                  Unblock
                </button>
              </div>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
