"use client";
import { useEffect, useState, useTransition } from "react";
import Link from "next/link";
import { ArrowLeft, KeyRound, Loader2, Search, ShieldCheck, UserPlus } from "lucide-react";
import {
  backfillMasterOperatorCreatedBy,
  createMasterOperator,
  findUserForMasterPanel,
  listMasterOperators,
  resetMasterOperatorPassword,
  setMasterOperatorActive,
  type MasterOperatorRow,
} from "./actions";
type FoundUser = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
};
export default function MasterPanelAccessPage() {
  const [operators, setOperators] = useState<MasterOperatorRow[]>([]);
  const [loadError, setLoadError] = useState("");
  const [loadingList, setLoadingList] = useState(true);
  const [query, setQuery] = useState("");
  const [users, setUsers] = useState<FoundUser[]>([]);
  const [searching, setSearching] = useState(false);
  const [selectedUser, setSelectedUser] = useState<FoundUser | null>(null);
  const [loginUsername, setLoginUsername] = useState("");
  const [password, setPassword] = useState("");
  const [formError, setFormError] = useState("");
  const [pending, startTransition] = useTransition();
  async function refresh() {
    setLoadingList(true);
    const res = await listMasterOperators();
    if (res.success) {
      setOperators(res.operators);
      setLoadError("");
    } else {
      setLoadError(res.error || "Failed to load");
    }
    setLoadingList(false);
  }
  useEffect(() => {
    void refresh();
  }, []);
  async function handleSearch() {
    setSearching(true);
    setFormError("");
    const res = await findUserForMasterPanel(query);
    if (res.success) setUsers((res.users || []) as FoundUser[]);
    else {
      setUsers([]);
      setFormError(res.error || "Search failed");
    }
    setSearching(false);
  }
  function pickUser(user: FoundUser) {
    setSelectedUser(user);
    setLoginUsername(
      (user.username || "")
        .toLowerCase()
        .replace(/[^a-z0-9_]/g, "")
        .slice(0, 32),
    );
    setPassword("");
    setFormError("");
  }
  function handleCreate() {
    if (!selectedUser) return;
    setFormError("");
    startTransition(async () => {
      const res = await createMasterOperator({
        userId: selectedUser.id,
        username: loginUsername,
        password,
      });
      if (!res.success) {
        setFormError(res.error);
        return;
      }
      setSelectedUser(null);
      setUsers([]);
      setQuery("");
      setLoginUsername("");
      setPassword("");
      await refresh();
    });
  }
  function handleToggle(op: MasterOperatorRow) {
    startTransition(async () => {
      const res = await setMasterOperatorActive(op.id, !op.is_active);
      if (!res.success) alert(res.error);
      else await refresh();
    });
  }
  function handleResetPassword(op: MasterOperatorRow) {
    const next = window.prompt(`New Master Panel password for @${op.username}`);
    if (!next) return;
    startTransition(async () => {
      const res = await resetMasterOperatorPassword(op.id, next);
      if (!res.success) alert(res.error);
      else alert("Password updated");
    });
  }
  function handleBackfill() {
    startTransition(async () => {
      const res = await backfillMasterOperatorCreatedBy();
      if (!res.success) {
        alert(res.error);
        return;
      }
      alert(
        `Backfill done: updated ${res.updated}, skipped ${res.skipped} (scanned ${res.scanned})`,
      );
      await refresh();
    });
  }
  return (
    <div className="space-y-10 pb-32 max-w-3xl">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Settings</span>
      </Link>

      <header>
        <div className="inline-flex p-3 bg-violet-500/20 rounded-2xl mb-4">
          <ShieldCheck className="text-violet-300" size={28} />
        </div>
        <h1 className="text-4xl font-black tracking-tight">Master Panel Access</h1>
        <p className="text-white/50 mt-2 max-w-xl">
          Assign Master Panel logins, then open each operator to see Super Admins / BDs / agencies
          they placed under their tree.
        </p>
        <button
          type="button"
          disabled={pending}
          onClick={handleBackfill}
          className="mt-4 px-4 py-2 rounded-xl bg-white/10 text-xs font-black uppercase tracking-widest text-white/70 hover:bg-white/15 disabled:opacity-50"
        >
          Backfill created-by from audit
        </button>
      </header>

      <section className="glass-card p-8 space-y-6">
        <h2 className="text-lg font-black flex items-center gap-2">
          <UserPlus size={18} className="text-violet-300" />
          Grant access
        </h2>

        <div className="flex gap-3">
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && void handleSearch()}
            placeholder="Search app user (username or short ID)"
            className="flex-1 bg-white/5 border border-white/10 rounded-2xl px-5 py-4 outline-none focus:border-violet-500"
          />
          <button
            type="button"
            onClick={() => void handleSearch()}
            disabled={searching}
            className="px-5 py-4 bg-white/10 hover:bg-white/20 rounded-2xl"
          >
            {searching ? <Loader2 className="animate-spin" /> : <Search size={20} />}
          </button>
        </div>

        {users.length > 0 && (
          <div className="space-y-2">
            {users.map((user) => (
              <button
                key={user.id}
                type="button"
                onClick={() => pickUser(user)}
                className={`w-full text-left flex items-center justify-between p-4 rounded-2xl border transition-colors ${
                  selectedUser?.id === user.id
                    ? "bg-violet-500/20 border-violet-500/40"
                    : "bg-white/5 border-white/5 hover:bg-white/10"
                }`}
              >
                <div>
                  <p className="font-bold">{user.username}</p>
                  <p className="text-xs text-white/40">Short ID: {user.short_id}</p>
                </div>
                <span className="text-[10px] font-black uppercase tracking-widest text-violet-300">
                  Select
                </span>
              </button>
            ))}
          </div>
        )}

        {selectedUser && (
          <div className="space-y-4 pt-2 border-t border-white/10">
            <p className="text-sm text-white/60">
              App user: <span className="text-white font-bold">{selectedUser.username}</span> (#
              {selectedUser.short_id})
            </p>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-white/40 ml-1">
                  Master Panel username
                </label>
                <input
                  value={loginUsername}
                  onChange={(e) => setLoginUsername(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-4 py-3 outline-none focus:border-violet-500"
                  placeholder="e.g. ops_ali"
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-white/40 ml-1">
                  Password (min 8)
                </label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-4 py-3 outline-none focus:border-violet-500"
                  placeholder="••••••••"
                />
              </div>
            </div>
            {formError && (
              <p className="text-red-400 text-sm font-medium bg-red-400/10 px-4 py-3 rounded-xl">
                {formError}
              </p>
            )}
            <button
              type="button"
              disabled={pending}
              onClick={handleCreate}
              className="inline-flex items-center gap-2 px-6 py-3 bg-violet-500 hover:bg-violet-400 text-black font-black rounded-xl disabled:opacity-60"
            >
              {pending ? <Loader2 className="animate-spin" size={16} /> : <KeyRound size={16} />}
              Create Master login
            </button>
          </div>
        )}
      </section>

      <section className="space-y-4">
        <h2 className="text-lg font-black">Current operators</h2>
        {loadingList && (
          <div className="flex items-center gap-2 text-white/40 text-sm">
            <Loader2 className="animate-spin" size={16} /> Loading…
          </div>
        )}
        {loadError && (
          <p className="text-amber-300 text-sm bg-amber-400/10 px-4 py-3 rounded-xl">{loadError}</p>
        )}
        {!loadingList && operators.length === 0 && !loadError && (
          <p className="text-white/40 text-sm">No Master Panel logins yet.</p>
        )}
        <div className="space-y-3">
          {operators.map((op) => {
            const t = op.totals;
            return (
              <div key={op.id} className="glass-card p-5 flex flex-col gap-4">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div>
                    <p className="font-black text-lg">@{op.username}</p>
                    <p className="text-sm text-white/50">
                      App: {op.users?.username ?? "—"} #{op.users?.short_id ?? "—"}
                    </p>
                    <p className="text-xs text-white/30 mt-1">
                      {op.is_active ? "Active" : "Disabled"}
                      {op.last_login_at
                        ? ` · Last login ${new Date(op.last_login_at).toLocaleString()}`
                        : " · Never logged in"}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <Link
                      href={`/settings/master-panel/${op.id}`}
                      className="px-4 py-2 rounded-xl bg-violet-500/20 text-violet-200 text-sm font-bold hover:bg-violet-500/30"
                    >
                      View tree
                    </Link>
                    <button
                      type="button"
                      disabled={pending}
                      onClick={() => handleResetPassword(op)}
                      className="px-4 py-2 rounded-xl bg-white/10 text-sm font-bold hover:bg-white/15"
                    >
                      Reset password
                    </button>
                    <button
                      type="button"
                      disabled={pending}
                      onClick={() => handleToggle(op)}
                      className={`px-4 py-2 rounded-xl text-sm font-bold ${
                        op.is_active
                          ? "bg-red-500/20 text-red-300 hover:bg-red-500/30"
                          : "bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30"
                      }`}
                    >
                      {op.is_active ? "Disable" : "Enable"}
                    </button>
                  </div>
                </div>
                {t && (
                  <div className="flex flex-wrap gap-2">
                    <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase tracking-widest text-white/60">
                      SA {t.superAdmins}
                    </span>
                    <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase tracking-widest text-white/60">
                      BD {t.bds}
                    </span>
                    <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase tracking-widest text-white/60">
                      Agencies {t.agencies}
                    </span>
                    <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase tracking-widest text-white/60">
                      Hosts {t.hosts}
                    </span>
                    <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase tracking-widest text-white/40">
                      Direct staff {t.directStaff}
                    </span>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </section>
    </div>
  );
}
