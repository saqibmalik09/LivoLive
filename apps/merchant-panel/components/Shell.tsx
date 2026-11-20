import Link from "next/link";
import { LogOut, Store, AlertTriangle } from "lucide-react";
import { Navigation } from "@/components/Navigation";
import { logoutAction } from "@/app/login/actions";

/** Page chrome: who you are, a blocked banner, nav, and sign out. */
export function Shell({
  username,
  displayName,
  shortId,
  blocked,
  blockedReason,
  children,
}: {
  username: string;
  displayName?: string | null;
  shortId?: number | null;
  blocked?: boolean;
  blockedReason?: string | null;
  children: React.ReactNode;
}) {
  return (
    <>
      <main className="max-w-5xl mx-auto px-5 pt-10 space-y-8">
        <header className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3 min-w-0">
            <div className="p-2.5 rounded-xl bg-emerald-500/15 text-emerald-300 shrink-0">
              <Store size={20} />
            </div>
            <div className="min-w-0">
              <p className="font-black text-lg truncate leading-tight">
                {displayName || username}
              </p>
              <p className="text-[11px] text-white/40">
                Merchant{shortId ? ` · ID ${shortId}` : ""} · @{username}
              </p>
            </div>
          </div>
          <form action={logoutAction}>
            <button
              type="submit"
              className="inline-flex items-center gap-2 bg-white/5 hover:bg-white/10 transition-colors text-[10px] font-black uppercase tracking-widest px-4 py-2.5 rounded-xl text-white/60 hover:text-white"
            >
              <LogOut size={13} /> Sign out
            </button>
          </form>
        </header>

        {blocked ? (
          <div className="glass-card !p-5 border border-rose-500/30 bg-rose-500/5">
            <p className="font-black text-rose-300 text-sm flex items-center gap-2">
              <AlertTriangle size={15} /> Your merchant account is blocked
            </p>
            <p className="text-xs text-white/50 mt-1">
              {blockedReason
                ? blockedReason
                : "You cannot send coins or request a payout. Please contact the admin."}
            </p>
          </div>
        ) : null}

        {children}
      </main>
      <Navigation />
    </>
  );
}

export function Empty({ children }: { children: React.ReactNode }) {
  return <div className="glass-card p-12 text-center text-white/40">{children}</div>;
}

export function BackLink({ href, label }: { href: string; label: string }) {
  return (
    <Link href={href} className="text-[10px] font-black uppercase tracking-widest text-white/40 hover:text-white">
      {label}
    </Link>
  );
}
