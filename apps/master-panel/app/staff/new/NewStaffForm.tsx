'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowLeft, Loader2, Search, UserPlus } from 'lucide-react';
import {
  createBusinessStaff,
  createSuperBd,
  findUserByQuery,
  type StaffCreateRole,
} from '../actions';
import { useRouter } from 'next/navigation';

type SuperBdOption = {
  id: string;
  staff_code: string;
  username: string;
  short_id: string | null;
};

const ROLE_OPTIONS: { value: StaffCreateRole; label: string }[] = [
  { value: 'super_bd', label: 'Super Admin' },
  { value: 'county_admin', label: 'Admin' },
  { value: 'assistant', label: 'Assistant' },
  { value: 'customer_service', label: 'CS' },
];

export default function NewStaffPage({
  superBdOptions,
}: {
  superBdOptions: SuperBdOption[];
}) {
  const router = useRouter();
  const [role, setRole] = useState<StaffCreateRole>('super_bd');
  const [parentStaffId, setParentStaffId] = useState(superBdOptions[0]?.id ?? '');
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [creating, setCreating] = useState<string | null>(null);

  async function handleSearch() {
    setLoading(true);
    const res = await findUserByQuery(query);
    if (res.success) setUsers(res.users || []);
    else alert(res.error);
    setLoading(false);
  }

  async function handleCreate(userId: string) {
    const label = ROLE_OPTIONS.find((r) => r.value === role)?.label || role;
    if (!confirm(`Create ${label} for this user?`)) return;
    setCreating(userId);

    let res;
    if (role === 'super_bd') {
      res = await createSuperBd(userId);
    } else {
      if (!parentStaffId) {
        alert('Select a parent Super Admin');
        setCreating(null);
        return;
      }
      res = await createBusinessStaff(userId, role, parentStaffId);
    }

    if (res.success) {
      router.push('/staff');
      router.refresh();
    } else {
      alert(res.error);
    }
    setCreating(null);
  }

  return (
    <div className="space-y-10 pb-32 max-w-2xl">
      <Link
        href="/staff"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Staff</span>
      </Link>

      <div>
        <h1 className="text-4xl font-black italic tracking-tight">Create Staff</h1>
        <p className="text-white/40 mt-2">
          Super Admin has no parent. Admin / Assistant / CS require an active Super Admin parent.
        </p>
      </div>

      <div className="glass-card p-8 space-y-5">
        <label className="block space-y-2">
          <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
            Role
          </span>
          <select
            value={role}
            onChange={(e) => setRole(e.target.value as StaffCreateRole)}
            className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 outline-none focus:border-amber-500"
          >
            {ROLE_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </label>

        {role !== 'super_bd' && (
          <label className="block space-y-2">
            <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
              Parent Super Admin
            </span>
            <select
              value={parentStaffId}
              onChange={(e) => setParentStaffId(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 outline-none focus:border-amber-500"
            >
              <option value="">Select Super Admin…</option>
              {superBdOptions.map((opt) => (
                <option key={opt.id} value={opt.id}>
                  {opt.username}
                  {opt.short_id ? ` · UID ${opt.short_id}` : ''} · {opt.staff_code}
                </option>
              ))}
            </select>
          </label>
        )}

        <div className="flex gap-3">
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Username or short ID"
            className="flex-1 bg-white/5 border border-white/10 rounded-2xl px-5 py-4 outline-none focus:border-amber-500"
          />
          <button
            onClick={handleSearch}
            disabled={loading}
            className="px-5 py-4 bg-white/10 hover:bg-white/20 rounded-2xl"
          >
            {loading ? <Loader2 className="animate-spin" /> : <Search size={20} />}
          </button>
        </div>

        <div className="space-y-3">
          {users.map((user) => (
            <div
              key={user.id}
              className="flex items-center justify-between p-4 bg-white/5 rounded-2xl border border-white/5"
            >
              <div>
                <p className="font-bold">{user.username}</p>
                <p className="text-xs text-white/40">Short ID: {user.short_id}</p>
              </div>
              <button
                onClick={() => handleCreate(user.id)}
                disabled={creating === user.id}
                className="inline-flex items-center gap-2 px-4 py-2 bg-amber-500 text-black font-black rounded-xl text-sm"
              >
                {creating === user.id ? (
                  <Loader2 className="animate-spin" size={16} />
                ) : (
                  <UserPlus size={16} />
                )}
                Assign
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
