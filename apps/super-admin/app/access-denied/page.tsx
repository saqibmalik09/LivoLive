import Link from 'next/link';
import { ShieldX } from 'lucide-react';
import { signOut } from '@/lib/actions';
import { createClient } from '@/lib/supabase/server';
import { fetchStaffGateInfo } from '@/lib/auth/require-super-bd';
import { staffRoleLabel } from '@/lib/permissions';

export default async function AccessDeniedPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const gate = await fetchStaffGateInfo();
  const isSuperBd =
    gate?.is_super_bd === true ||
    gate?.staff_role === 'super_bd';

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="glass-card max-w-md w-full p-10 text-center space-y-6">
        <ShieldX className="mx-auto text-red-400" size={48} />
        <h1 className="text-2xl font-black">Access Denied</h1>
        <p className="text-white/60 text-sm leading-relaxed">
          This portal is for active <strong className="text-amber-400">Super Admin</strong> accounts
          only. Country Admin, BD, and other staff use the SK LIVE app Staff Center.
        </p>

        {user && (
          <div className="rounded-xl border border-white/10 bg-white/5 p-4 text-left text-sm space-y-2">
            <p>
              <span className="text-white/40">Logged in as:</span>{' '}
              <span className="font-mono text-white/80">{user.email || user.phone || user.id}</span>
            </p>
            {gate?.username && (
              <p>
                <span className="text-white/40">App profile:</span>{' '}
                {gate.username} (ID {gate.short_id ?? '—'})
              </p>
            )}
            {gate?.staff_role ? (
              <p>
                <span className="text-white/40">Your staff role:</span>{' '}
                <span className="text-amber-300">{staffRoleLabel(gate.staff_role)}</span>
                {!isSuperBd && (
                  <span className="block text-xs text-white/50 mt-1">
                    Only Super Admin can open this web panel.
                  </span>
                )}
              </p>
            ) : (
              <p className="text-white/50">No staff role on this login account.</p>
            )}
            {isSuperBd && (
              <p className="text-xs text-emerald-300/80 pt-2 border-t border-white/10">
                You are Super Admin.{' '}
                <Link href="/" className="underline hover:text-white">
                  Go to dashboard
                </Link>
              </p>
            )}
          </div>
        )}

        <form action={signOut}>
          <button type="submit" className="btn-ghost w-full">
            Sign out &amp; try another account
          </button>
        </form>
        <Link href="/login" className="text-xs text-white/40 hover:text-white block">
          Back to login
        </Link>
      </div>
    </div>
  );
}
