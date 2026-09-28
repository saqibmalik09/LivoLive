import { supabaseAdmin } from '@/lib/supabase';
import { ADMIN_AUDIT_ACTION_LABELS } from '@/lib/admin-audit';
import Link from 'next/link';
import { ArrowLeft, ScrollText } from 'lucide-react';
import { format } from 'date-fns';

export default async function AuditPage() {
  const { data: logs, error } = await supabaseAdmin
    .from('admin_audit_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(50);

  return (
    <div className="space-y-8 pb-32">
      <div>
        <Link
          href="/"
          className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group mb-2"
        >
          <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
          <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
        </Link>
        <h1 className="text-4xl font-black tracking-tight flex items-center gap-3">
          <ScrollText className="text-purple-400" />
          Audit log
        </h1>
        <p className="text-white/40 mt-2">Read-only · last 50 entries</p>
      </div>

      {error && (
        <div className="rounded-2xl border border-red-500/30 bg-red-500/10 px-6 py-4 text-sm text-red-200">
          Failed to load audit logs: {error.message}
        </div>
      )}

      <div className="glass-card !p-0 overflow-hidden">
        <div className="divide-y divide-white/5">
          {(logs || []).map((log: any) => (
            <div key={log.id} className="px-6 py-4 space-y-1">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <p className="font-bold text-sm">
                  {ADMIN_AUDIT_ACTION_LABELS[log.action] || log.action}
                </p>
                <p className="text-[10px] font-mono text-white/30">
                  {log.created_at
                    ? format(new Date(log.created_at), 'yyyy-MM-dd HH:mm:ss')
                    : '—'}
                </p>
              </div>
              <p className="text-sm text-white/60">{log.summary || '—'}</p>
              <p className="text-[10px] uppercase tracking-widest text-white/30">
                {log.source} · {log.actor_label || '—'}
                {log.success === false ? ' · FAILED' : ''}
              </p>
            </div>
          ))}
          {(logs || []).length === 0 && (
            <div className="px-6 py-16 text-center text-white/30">No audit entries yet.</div>
          )}
        </div>
      </div>
    </div>
  );
}
