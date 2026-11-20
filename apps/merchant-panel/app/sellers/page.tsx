import { redirect } from "next/navigation";
import Link from "next/link";
import { User } from "lucide-react";
import { getMerchantActor } from "@/lib/merchant-session";
import { getOverview, getSellers, fmtCoins, fmtDate } from "@/lib/merchant-data";
import { Shell, Empty } from "@/components/Shell";

export const dynamic = "force-dynamic";

export default async function SellersPage() {
  const actor = await getMerchantActor();
  if (!actor) redirect("/login");
  if (actor.mustChangePassword) redirect("/change-password");

  const [o, sellers] = await Promise.all([
    getOverview(actor.userId),
    getSellers(actor.userId),
  ]);

  return (
    <Shell
      username={actor.username}
      displayName={o?.display_name}
      shortId={o?.short_id}
      blocked={o?.is_blocked}
      blockedReason={o?.blocked_reason}
    >
      <div className="flex items-baseline justify-between gap-3 flex-wrap">
        <h1 className="text-lg font-black">My coin sellers</h1>
        <p className="text-xs text-white/40">{sellers.length} total</p>
      </div>

      {sellers.length === 0 ? (
        <Empty>
          You have not supplied any coin seller yet. Use{" "}
          <Link href="/recharge" className="text-emerald-300 font-bold">
            Recharge
          </Link>{" "}
          to send coins to a seller by their ID.
        </Empty>
      ) : (
        <div className="space-y-2">
          {sellers.map((s) => (
            <div key={s.id} className="glass-card !p-4 space-y-3">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl overflow-hidden bg-white/10 shrink-0 flex items-center justify-center">
                  {s.avatar_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={s.avatar_url} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <User size={16} className="text-white/30" />
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-bold text-sm truncate flex items-center gap-2">
                    {s.username ?? "Seller"}
                    {s.is_linked ? (
                      <span className="text-[9px] font-black uppercase tracking-widest text-emerald-400 bg-emerald-500/15 px-2 py-0.5 rounded">
                        Yours
                      </span>
                    ) : null}
                    {s.is_banned ? (
                      <span className="text-[9px] font-black uppercase tracking-widest text-rose-400 bg-rose-500/15 px-2 py-0.5 rounded">
                        Banned
                      </span>
                    ) : null}
                  </p>
                  <p className="text-[11px] text-white/40">
                    ID {s.short_id ?? "—"} · their stock {fmtCoins(s.reseller_coins)}
                  </p>
                </div>
                <Link
                  href="/recharge"
                  className="text-[10px] font-black uppercase tracking-widest text-emerald-300/80 hover:text-emerald-300 shrink-0"
                >
                  Recharge
                </Link>
              </div>
              <div className="grid grid-cols-3 gap-2">
                <Mini label="You supplied" value={fmtCoins(s.total_supplied)} />
                <Mini label="Times" value={fmtCoins(s.supply_count)} />
                <Mini label="Last" value={fmtDate(s.last_supplied_at)} />
              </div>
            </div>
          ))}
        </div>
      )}
    </Shell>
  );
}

function Mini({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white/5 rounded-xl p-3 text-center">
      <p className="text-xs font-black">{value}</p>
      <p className="text-[9px] font-black uppercase tracking-widest text-white/40 mt-0.5">
        {label}
      </p>
    </div>
  );
}
