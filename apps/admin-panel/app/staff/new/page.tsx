"use client";
import { useState } from "react";
import Link from "next/link";
import { ArrowLeft, Loader2, Search, UserPlus } from "lucide-react";
import { createSuperBd, findUserByQuery } from "../actions";
import { useRouter } from "next/navigation";
export default function NewStaffPage() {
  const router = useRouter();
  const [query, setQuery] = useState("");
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
    if (!confirm("Create Super Admin for this user?")) return;
    setCreating(userId);
    const res = await createSuperBd(userId);
    if (res.success) {
      router.push("/staff");
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
        <span className="text-[10px] font-black uppercase tracking-widest">Staff Chain</span>
      </Link>

      <div>
        <h1 className="text-4xl font-black italic tracking-tight">Create Super Admin</h1>
        <p className="text-white/40 mt-2">Search an app user by username or short ID.</p>
      </div>

      <div className="glass-card p-8 space-y-4">
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
