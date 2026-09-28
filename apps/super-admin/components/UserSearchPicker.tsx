'use client';

import { useState, useTransition } from 'react';
import { toast } from 'sonner';
import { Search, Loader2, UserPlus } from 'lucide-react';
import type { SearchUser } from '@/lib/types';
import { staffRoleLabel, type ChildStaffRole } from '@/lib/permissions';
import { searchUsers, createStaffMember } from '@/lib/actions';

type UserSearchPickerProps = {
  childRole: ChildStaffRole;
  creatableRoles: ChildStaffRole[];
  actionLabel: string;
};

export function UserSearchPicker({
  childRole,
  creatableRoles,
  actionLabel,
}: UserSearchPickerProps) {
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState<SearchUser[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [selectedRole, setSelectedRole] = useState<ChildStaffRole>(
    creatableRoles.includes(childRole) ? childRole : creatableRoles[0],
  );
  const [searching, startSearch] = useTransition();
  const [creating, startCreate] = useTransition();

  const roleName = staffRoleLabel(selectedRole);

  function onSearch() {
    startSearch(async () => {
      const res = await searchUsers(query);
      if (res.success) setUsers(res.users);
      else toast.error(res.error || 'Search failed');
    });
  }

  function onCreate() {
    if (!selected) return;
    startCreate(async () => {
      const res = await createStaffMember(selected, selectedRole);
      if (res.success) {
        toast.success(`${roleName} created. Staff code: ${res.staff_code}`);
        setQuery('');
        setUsers([]);
        setSelected(null);
      } else {
        toast.error(res.error || `Failed to create ${roleName}`);
      }
    });
  }

  return (
    <div className="glass-card p-6 md:p-8 space-y-6">
      <div>
        <h2 className="text-lg font-black">Search by Short ID or Username</h2>
        <p className="text-sm text-white/50 mt-1">User must already have a SK LIVE account.</p>
      </div>

      {creatableRoles.length > 1 && (
        <label className="block space-y-2">
          <span className="text-xs font-bold uppercase tracking-widest text-white/40">Role</span>
          <select
            value={selectedRole}
            onChange={(e) => setSelectedRole(e.target.value as ChildStaffRole)}
            className="input-field w-full"
          >
            {creatableRoles.map((r) => (
              <option key={r} value={r}>
                {staffRoleLabel(r)}
              </option>
            ))}
          </select>
        </label>
      )}

      <div className="flex flex-col sm:flex-row gap-3">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && onSearch()}
          placeholder="e.g. 1283 or username"
          className="input-field flex-1"
        />
        <button type="button" onClick={onSearch} disabled={searching} className="btn-ghost shrink-0">
          {searching ? <Loader2 className="animate-spin" size={18} /> : <Search size={18} />}
          Search
        </button>
      </div>

      {users.length > 0 && (
        <div className="space-y-2">
          {users.map((u) => (
            <label
              key={u.id}
              className={`flex items-center gap-4 p-4 rounded-xl border cursor-pointer transition ${
                selected === u.id ? 'border-amber-500/50 bg-amber-500/10' : 'border-white/10 hover:bg-white/5'
              }`}
            >
              <input
                type="radio"
                name="user"
                checked={selected === u.id}
                onChange={() => setSelected(u.id)}
                className="accent-amber-500"
              />
              {u.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={u.avatar_url} alt="" className="w-10 h-10 rounded-full object-cover" />
              ) : (
                <div className="w-10 h-10 rounded-full bg-white/10" />
              )}
              <div>
                <p className="font-semibold">{u.username}</p>
                <p className="text-xs text-white/40">ID {u.short_id}</p>
              </div>
            </label>
          ))}
        </div>
      )}

      <button
        type="button"
        onClick={onCreate}
        disabled={!selected || creating}
        className="btn-primary w-full sm:w-auto"
      >
        {creating ? <Loader2 className="animate-spin" size={18} /> : <UserPlus size={18} />}
        {actionLabel}
      </button>
    </div>
  );
}
