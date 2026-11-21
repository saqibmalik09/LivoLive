"use client";
import { CdnImg } from "@/components/CdnImg";
import { useCallback, useEffect, useState } from "react";
import {
  addGameVisibilityUser,
  clearGameVisibility,
  getGameVisibility,
  removeGameVisibilityUser,
  searchUsersForGameAudience,
  setGameVisibilityMode,
  type VisibilityMode,
  type VisibilityScope,
} from "@/app/settings/game-control/actions";
import { Loader2, Search, Users, X } from "lucide-react";
type AudienceUser = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
};
export function GameAudienceButton({
  scope,
  targetId,
  label,
}: {
  scope: VisibilityScope;
  targetId: string;
  label: string;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-violet-500/15 text-violet-200 text-xs font-bold hover:bg-violet-500/25"
        title="Who can see this"
      >
        <Users size={14} />
        Audience
      </button>
      {open ? (
        <GameAudienceModal
          scope={scope}
          targetId={targetId}
          label={label}
          onClose={() => setOpen(false)}
        />
      ) : null}
    </>
  );
}
function GameAudienceModal({
  scope,
  targetId,
  label,
  onClose,
}: {
  scope: VisibilityScope;
  targetId: string;
  label: string;
  onClose: () => void;
}) {
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [mode, setMode] = useState<VisibilityMode>("hide_from");
  const [users, setUsers] = useState<AudienceUser[]>([]);
  const [query, setQuery] = useState("");
  const [hits, setHits] = useState<AudienceUser[]>([]);
  const [searching, setSearching] = useState(false);
  const reload = useCallback(async () => {
    setLoading(true);
    const res = await getGameVisibility(scope, targetId);
    if (res.success) {
      setMode(res.mode ?? "hide_from");
      setUsers(res.users);
    } else {
      alert(res.error);
    }
    setLoading(false);
  }, [scope, targetId]);
  useEffect(() => {
    void reload();
  }, [reload]);
  useEffect(() => {
    const q = query.trim();
    if (q.length < 1) {
      setHits([]);
      return;
    }
    let cancelled = false;
    const t = setTimeout(async () => {
      setSearching(true);
      const res = await searchUsersForGameAudience(q);
      if (!cancelled) {
        if (res.success) setHits(res.users as AudienceUser[]);
        else setHits([]);
        setSearching(false);
      }
    }, 280);
    return () => {
      cancelled = true;
      clearTimeout(t);
    };
  }, [query]);
  async function changeMode(next: VisibilityMode) {
    setMode(next);
    if (users.length === 0) return;
    setBusy(true);
    const res = await setGameVisibilityMode(scope, targetId, next);
    if (!res.success) alert(res.error);
    setBusy(false);
  }
  async function addUser(u: AudienceUser) {
    if (users.some((x) => x.id === u.id)) return;
    setBusy(true);
    const res = await addGameVisibilityUser({
      scope,
      targetId,
      userId: u.id,
      mode,
    });
    if (!res.success) alert(res.error);
    else {
      setUsers((prev) => [...prev, u]);
      setQuery("");
      setHits([]);
    }
    setBusy(false);
  }
  async function removeUser(userId: string) {
    setBusy(true);
    const res = await removeGameVisibilityUser({ scope, targetId, userId });
    if (!res.success) alert(res.error);
    else setUsers((prev) => prev.filter((u) => u.id !== userId));
    setBusy(false);
  }
  async function clearAll() {
    if (!confirm("Clear audience rules? Everyone will see this again.")) return;
    setBusy(true);
    const res = await clearGameVisibility(scope, targetId);
    if (!res.success) alert(res.error);
    else {
      setUsers([]);
      setMode("hide_from");
    }
    setBusy(false);
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-3xl border border-white/10 bg-[#12121a] shadow-2xl">
        <div className="flex items-start justify-between gap-3 border-b border-white/10 p-5">
          <div>
            <h3 className="text-lg font-black tracking-tight">Audience</h3>
            <p className="mt-1 text-sm text-white/50">{label}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white"
          >
            <X size={18} />
          </button>
        </div>

        <div className="space-y-5 p-5">
          {loading ? (
            <div className="flex justify-center py-10 text-white/40">
              <Loader2 className="animate-spin" />
            </div>
          ) : (
            <>
              <div className="space-y-2">
                <p className="text-[11px] font-bold uppercase tracking-wider text-white/40">Rule</p>
                <div className="flex flex-wrap gap-2">
                  {(
                    [
                      {
                        value: "hide_from" as const,
                        label: "Hide from these users",
                        hint: "Everyone else still sees it",
                      },
                      {
                        value: "show_only" as const,
                        label: "Show only to these users",
                        hint: "Hidden from everyone else",
                      },
                    ] as const
                  ).map((opt) => (
                    <button
                      key={opt.value}
                      type="button"
                      disabled={busy}
                      onClick={() => changeMode(opt.value)}
                      className={`rounded-2xl border px-4 py-3 text-left text-sm transition-all ${
                        mode === opt.value
                          ? "border-violet-400 bg-violet-500/20 text-violet-100"
                          : "border-white/10 bg-black/30 text-white/55 hover:border-white/25"
                      }`}
                    >
                      <div className="font-bold">{opt.label}</div>
                      <div className="mt-0.5 text-[11px] opacity-70">{opt.hint}</div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-2">
                <p className="text-[11px] font-bold uppercase tracking-wider text-white/40">
                  Search users
                </p>
                <label className="relative block">
                  <Search
                    size={16}
                    className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-white/40"
                  />
                  <input
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Username or short ID…"
                    className="w-full rounded-xl border border-white/10 bg-black/30 py-2.5 pl-10 pr-3 text-sm outline-none focus:border-violet-400/50"
                  />
                </label>
                {searching ? <p className="text-xs text-white/35">Searching…</p> : null}
                {hits.length > 0 ? (
                  <ul className="max-h-40 overflow-y-auto rounded-xl border border-white/10 divide-y divide-white/5">
                    {hits.map((u) => (
                      <li key={u.id}>
                        <button
                          type="button"
                          disabled={busy || users.some((x) => x.id === u.id)}
                          onClick={() => addUser(u)}
                          className="flex w-full items-center gap-3 px-3 py-2 text-left hover:bg-white/5 disabled:opacity-40"
                        >
                          {u.avatar_url ? (
                            <CdnImg
                              src={u.avatar_url}
                              alt=""
                              className="h-8 w-8 rounded-full object-cover"
                            />
                          ) : (
                            <div className="h-8 w-8 rounded-full bg-white/10" />
                          )}
                          <div className="min-w-0">
                            <div className="truncate text-sm font-bold">{u.username || "User"}</div>
                            <div className="font-mono text-[10px] text-white/40">
                              ID {u.short_id ?? "—"}
                            </div>
                          </div>
                          <span className="ml-auto text-xs font-bold text-violet-300">Add</span>
                        </button>
                      </li>
                    ))}
                  </ul>
                ) : null}
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <p className="text-[11px] font-bold uppercase tracking-wider text-white/40">
                    Selected ({users.length})
                  </p>
                  {users.length > 0 ? (
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => clearAll()}
                      className="text-xs font-bold text-red-300/80 hover:text-red-200"
                    >
                      Clear all
                    </button>
                  ) : null}
                </div>
                {users.length === 0 ? (
                  <p className="rounded-xl border border-dashed border-white/10 px-3 py-4 text-sm text-white/40">
                    No users selected — everyone can see this.
                  </p>
                ) : (
                  <ul className="max-h-48 space-y-2 overflow-y-auto">
                    {users.map((u) => (
                      <li
                        key={u.id}
                        className="flex items-center gap-3 rounded-xl border border-white/10 bg-black/25 px-3 py-2"
                      >
                        {u.avatar_url ? (
                          <CdnImg
                            src={u.avatar_url}
                            alt=""
                            className="h-8 w-8 rounded-full object-cover"
                          />
                        ) : (
                          <div className="h-8 w-8 rounded-full bg-white/10" />
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-sm font-bold">{u.username || "User"}</div>
                          <div className="font-mono text-[10px] text-white/40">
                            ID {u.short_id ?? "—"}
                          </div>
                        </div>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => removeUser(u.id)}
                          className="rounded-lg p-1.5 text-white/40 hover:bg-white/10 hover:text-white"
                        >
                          <X size={14} />
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
