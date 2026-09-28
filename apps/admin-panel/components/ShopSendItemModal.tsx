"use client";
import { useCallback, useEffect, useState, useTransition } from "react";
import { Gift, Loader2, Search, User, X } from "lucide-react";
import {
  searchUsersForShopGrant,
  sendShopItemToUser,
  type ShopUserSearchResult,
} from "@/app/shop/actions";
const DAY_PRESETS = [1, 3, 7, 15, 30, 90, 365];
type Props = {
  itemId: string;
  itemName: string;
  defaultDays: number;
  open: boolean;
  onClose: () => void;
};
export function ShopSendItemModal({ itemId, itemName, defaultDays, open, onClose }: Props) {
  const [query, setQuery] = useState("");
  const [users, setUsers] = useState<ShopUserSearchResult[]>([]);
  const [selected, setSelected] = useState<ShopUserSearchResult | null>(null);
  const [days, setDays] = useState(defaultDays > 0 ? defaultDays : 7);
  const [permanent, setPermanent] = useState(defaultDays <= 0);
  const [equip, setEquip] = useState(false);
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  useEffect(() => {
    if (!open) return;
    setQuery("");
    setUsers([]);
    setSelected(null);
    setDays(defaultDays > 0 ? defaultDays : 7);
    setPermanent(defaultDays <= 0);
    setEquip(false);
    setError(null);
    setSuccess(null);
  }, [open, defaultDays, itemId]);
  const runSearch = useCallback(async (q: string) => {
    if (q.trim().length < 1) {
      setUsers([]);
      return;
    }
    setSearching(true);
    const res = await searchUsersForShopGrant(q);
    setSearching(false);
    if (res.success) setUsers(res.users);
    else setError(res.error);
  }, []);
  useEffect(() => {
    if (!open) return;
    const t = setTimeout(() => {
      void runSearch(query);
    }, 300);
    return () => clearTimeout(t);
  }, [query, open, runSearch]);
  if (!open) return null;
  function submit() {
    if (!selected) {
      setError("Select a user first");
      return;
    }
    setError(null);
    setSuccess(null);
    startTransition(async () => {
      const res = await sendShopItemToUser({
        itemId,
        userId: selected.id,
        durationDays: permanent ? 0 : days,
        equip,
      });
      if (!res.success) {
        setError(res.error);
        return;
      }
      setSuccess(res.message);
    });
  }
  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center p-4">
      <button
        type="button"
        className="absolute inset-0 bg-black/70 backdrop-blur-sm"
        aria-label="Close"
        onClick={onClose}
      />
      <div className="relative w-full max-w-lg glass-card border border-amber-500/30 p-6 space-y-5 max-h-[90vh] overflow-y-auto">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/70">
              Send to user
            </p>
            <h2 className="text-2xl font-black tracking-tight">{itemName}</h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/50"
          >
            <X size={18} />
          </button>
        </div>

        <div className="space-y-2">
          <label className="text-[10px] font-black uppercase tracking-widest text-white/40">
            Find user (ID / username)
          </label>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-white/25" size={16} />
            <input
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setSelected(null);
                setSuccess(null);
              }}
              placeholder="Short ID or username…"
              className="w-full bg-black/40 border border-white/10 rounded-xl pl-10 pr-4 py-3 text-sm font-medium outline-none focus:border-amber-500/40"
              autoFocus
            />
            {searching && (
              <Loader2
                className="absolute right-3 top-1/2 -translate-y-1/2 animate-spin text-white/30"
                size={16}
              />
            )}
          </div>

          {selected ? (
            <div className="flex items-center gap-3 p-3 rounded-xl bg-amber-500/10 border border-amber-500/30">
              <UserAvatar user={selected} />
              <div className="min-w-0 flex-1">
                <p className="font-bold truncate">@{selected.username}</p>
                <p className="text-xs text-white/40">ID {selected.short_id || "—"}</p>
              </div>
              <button
                type="button"
                className="text-[10px] font-black uppercase tracking-widest text-white/40 hover:text-white"
                onClick={() => setSelected(null)}
              >
                Change
              </button>
            </div>
          ) : (
            <div className="max-h-48 overflow-y-auto space-y-1 rounded-xl border border-white/5 bg-black/20">
              {users.length === 0 && query.trim() && !searching && (
                <p className="text-sm text-white/30 p-4 text-center">No users found</p>
              )}
              {users.map((u) => (
                <button
                  key={u.id}
                  type="button"
                  onClick={() => {
                    setSelected(u);
                    setError(null);
                  }}
                  className="w-full flex items-center gap-3 p-3 hover:bg-white/5 text-left transition-colors"
                >
                  <UserAvatar user={u} />
                  <div className="min-w-0">
                    <p className="font-bold truncate">@{u.username}</p>
                    <p className="text-xs text-white/40">ID {u.short_id || "—"}</p>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="space-y-3">
          <label className="text-[10px] font-black uppercase tracking-widest text-white/40">
            Duration
          </label>
          <label className="flex items-center gap-2 text-sm text-white/70 cursor-pointer">
            <input
              type="checkbox"
              checked={permanent}
              onChange={(e) => setPermanent(e.target.checked)}
              className="rounded border-white/20"
            />
            Permanent (no expiry)
          </label>
          {!permanent && (
            <>
              <div className="flex flex-wrap gap-2">
                {DAY_PRESETS.map((d) => (
                  <button
                    key={d}
                    type="button"
                    onClick={() => setDays(d)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-black border transition-all ${
                      days === d
                        ? "bg-amber-500/25 border-amber-400/40 text-amber-200"
                        : "bg-white/5 border-white/10 text-white/40 hover:text-white"
                    }`}
                  >
                    {d}d
                  </button>
                ))}
              </div>
              <div className="flex items-center gap-3">
                <input
                  type="number"
                  min={1}
                  max={3650}
                  value={days}
                  onChange={(e) => setDays(Math.max(1, Math.floor(Number(e.target.value) || 1)))}
                  className="w-28 bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm font-bold outline-none focus:border-amber-500/40"
                />
                <span className="text-xs text-white/40 font-bold uppercase tracking-widest">
                  Days
                </span>
              </div>
            </>
          )}
        </div>

        <label className="flex items-center gap-2 text-sm text-white/70 cursor-pointer">
          <input
            type="checkbox"
            checked={equip}
            onChange={(e) => setEquip(e.target.checked)}
            className="rounded border-white/20"
          />
          Equip immediately after send
        </label>

        {error && (
          <p className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-3 py-2">
            {error}
          </p>
        )}
        {success && (
          <p className="text-sm text-emerald-300 bg-emerald-500/10 border border-emerald-500/20 rounded-xl px-3 py-2">
            {success}
          </p>
        )}

        <div className="flex gap-3 pt-1">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-3 rounded-xl border border-white/10 text-[10px] font-black uppercase tracking-widest text-white/50 hover:text-white"
          >
            Close
          </button>
          <button
            type="button"
            disabled={pending || !selected}
            onClick={submit}
            className="flex-1 py-3 rounded-xl bg-gradient-to-r from-amber-500 to-orange-600 text-black text-[10px] font-black uppercase tracking-widest disabled:opacity-40 flex items-center justify-center gap-2"
          >
            {pending ? <Loader2 size={16} className="animate-spin" /> : <Gift size={16} />}
            Send item
          </button>
        </div>
      </div>
    </div>
  );
}
function UserAvatar({ user }: { user: ShopUserSearchResult }) {
  if (user.avatar_url) {
    return (
      <img
        src={user.avatar_url}
        alt=""
        className="w-10 h-10 rounded-full object-cover border border-white/10 shrink-0"
      />
    );
  }
  return (
    <div className="w-10 h-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-amber-400 shrink-0">
      <User size={18} />
    </div>
  );
}
