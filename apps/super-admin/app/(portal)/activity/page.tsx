import Link from 'next/link';
import { requireStaff, fetchHierarchy } from '@/lib/auth/require-super-bd';
import { PORTAL_AUDIT_LABELS } from '@/lib/admin-audit';
import { getPortalPermissions } from '@/lib/permissions';
import type { HierarchyResponse } from '@/lib/types';
import { ScrollText } from 'lucide-react';

function actionLabel(action: string) {
  return PORTAL_AUDIT_LABELS[action] || action;
}

function sourceLabel(source: string) {
  if (source === 'sklive-flutter') return 'Mobile app';
  if (source === 'sklive-admin') return 'Admin panel';
  return 'Staff web';
}

export default async function ActivityPage({
  searchParams,
}: {
  searchParams: Promise<{ actor?: string }>;
}) {
  const sp = await searchParams;
  const { supabase, staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);

  let people: Array<{ id: string; label: string }> = [
    { id: staff.id, label: 'My activity' },
  ];

  if (permissions.canBanUnban) {
    try {
      const data = (await fetchHierarchy()) as HierarchyResponse;
      const supers = (data.tree?.staff || []).filter((n) => n.role === 'super_bd');
      for (const n of supers) {
        if (n.id === staff.id) continue;
        people.push({
          id: n.id,
          label: `${n.username} (#${n.short_id})`,
        });
      }
      // Always show self with name too if we have me
      if (data.me) {
        people[0] = {
          id: data.me.staff_id,
          label: `Me · ${data.me.username} (#${data.me.short_id})`,
        };
      }
    } catch {
      // keep My activity only
    }
  }

  const actor = sp.actor || staff.id;

  const { data: rows, error } = await supabase.rpc('list_admin_audit_logs', {
    p_limit: 150,
    p_action: null,
    p_source: null,
    p_actor_staff_id: actor,
  });
  if (error) console.error(error.message);

  const list = (rows || []) as Array<{
    id: string;
    created_at: string;
    actor_label: string | null;
    action: string;
    summary: string | null;
    source: string;
    success: boolean;
  }>;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-black tracking-tight flex items-center gap-3">
          <ScrollText className="text-amber-400" size={32} />
          Activity
        </h1>
        <p className="text-white/50 mt-2 text-sm max-w-xl">
          Har Super Admin ki activity alag — Mobile app aur Staff web dono se.
        </p>
      </div>

      <div className="flex flex-wrap gap-2">
        {people.map((p) => {
          const active = actor === p.id;
          return (
            <Link
              key={p.id}
              href={`/activity?actor=${p.id}`}
              className={`px-4 py-2 rounded-xl text-xs font-black tracking-wide ${
                active
                  ? 'bg-emerald-500/90 text-black'
                  : 'bg-white/5 text-white/50 border border-white/10'
              }`}
            >
              {p.label}
            </Link>
          );
        })}
      </div>

      <div className="space-y-2">
        {list.length === 0 ? (
          <div className="rounded-2xl border border-white/10 bg-white/5 p-10 text-center text-white/40">
            No activity for this Super Admin yet
          </div>
        ) : (
          list.map((r) => (
            <div
              key={r.id}
              className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 flex flex-wrap items-start justify-between gap-3"
            >
              <div className="min-w-0">
                <p className="font-bold">{actionLabel(r.action)}</p>
                <p className="text-sm text-white/55 mt-1">{r.summary || '—'}</p>
                <p className="text-[11px] text-white/30 mt-2">
                  By {r.actor_label || 'Staff'} · {sourceLabel(r.source)}
                  {r.success === false ? ' · FAILED' : ''}
                </p>
              </div>
              <p className="text-[11px] text-white/30 shrink-0">
                {new Date(r.created_at).toLocaleString()}
              </p>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
