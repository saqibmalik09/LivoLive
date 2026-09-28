"use client";
import { useState } from "react";
import { Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { setResellerFlag } from "../actions";
type Merchant = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
  country_code: string | null;
  created_at: string | null;
  reseller_coins: number | null;
  is_reseller: boolean | null;
};
export function MerchantsClient({ merchants }: { merchants: Merchant[] }) {
  const router = useRouter();
  const [loadingId, setLoadingId] = useState<string | null>(null);
  async function toggle(id: string, next: boolean) {
    setLoadingId(id);
    const res = await setResellerFlag(id, next);
    if (!res.success) alert(res.error);
    else router.refresh();
    setLoadingId(null);
  }
  if (merchants.length === 0) {
    return (
      <div className="glass-card p-12 text-center text-white/40">
        No coin merchants (resellers) yet. Enable reseller on a user profile.
      </div>
    );
  }
  return (
    <div className="space-y-3">
      {merchants.map((m) => (
        <div
          key={m.id}
          className="glass-card !p-5 flex flex-wrap items-center gap-4 justify-between"
        >
          <div className="flex items-center gap-4 min-w-0">
            <div className="w-12 h-12 rounded-xl overflow-hidden bg-white/10 shrink-0">
              {m.avatar_url ? (
                <img src={m.avatar_url} alt="" className="w-full h-full object-cover" />
              ) : null}
            </div>
            <div className="min-w-0">
              <p className="font-black truncate">{m.username || "User"}</p>
              <p className="text-xs text-white/40">
                ID {m.short_id ?? "—"} · {m.country_code || "—"} · stock{" "}
                {(m.reseller_coins ?? 0).toLocaleString()}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-[10px] font-black uppercase tracking-widest text-emerald-400">
              Merchant
            </span>
            <button
              disabled={loadingId === m.id}
              onClick={() => toggle(m.id, false)}
              className="px-4 py-2 rounded-xl bg-red-500/20 text-red-300 text-xs font-black"
            >
              {loadingId === m.id ? <Loader2 size={14} className="animate-spin" /> : "Revoke"}
            </button>
            <a
              href={`/users/${m.id}`}
              className="px-4 py-2 rounded-xl bg-white/10 text-xs font-black"
            >
              Open user
            </a>
          </div>
        </div>
      ))}
    </div>
  );
}
