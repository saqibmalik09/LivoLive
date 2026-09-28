'use client';

import { useState, useTransition } from 'react';
import { toast } from 'sonner';
import { Check, X, Loader2 } from 'lucide-react';
import type { AgencyApplication } from '@/lib/types';
import { approveApplication, rejectApplication } from '@/lib/actions';

export function ApplicationCard({ app }: { app: AgencyApplication }) {
  const [pending, startTransition] = useTransition();

  function act(action: 'approve' | 'reject') {
    startTransition(async () => {
      const res =
        action === 'approve'
          ? await approveApplication(app.id)
          : await rejectApplication(app.id);
      if (res.success) {
        toast.success(action === 'approve' ? 'Agency approved' : 'Application rejected');
      } else {
        toast.error(res.error || 'Action failed');
      }
    });
  }

  return (
    <div className="glass-card p-5 md:p-6 space-y-4">
      <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
        <div className="flex items-center gap-4">
          {app.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={app.avatar_url} alt="" className="w-12 h-12 rounded-full object-cover" />
          ) : (
            <div className="w-12 h-12 rounded-full bg-white/10" />
          )}
          <div>
            <p className="font-bold text-lg">{app.username}</p>
            <p className="text-xs text-white/40">ID {app.short_id}</p>
            {app.real_name && <p className="text-sm text-white/60 mt-1">{app.real_name}</p>}
          </div>
        </div>
        <div className="text-xs text-white/40">
          <p>Target: {app.target_staff_username}</p>
          <p>
            {app.target_staff_role} · {app.target_staff_code}
          </p>
          <p>{new Date(app.created_at).toLocaleString()}</p>
        </div>
      </div>
      <div className="flex flex-wrap gap-3">
        <button
          type="button"
          disabled={pending}
          onClick={() => act('approve')}
          className="btn-primary flex-1 sm:flex-none min-w-[120px]"
        >
          {pending ? <Loader2 className="animate-spin" size={16} /> : <Check size={16} />}
          Approve
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => act('reject')}
          className="btn-ghost flex-1 sm:flex-none min-w-[120px] border-red-500/30 text-red-300"
        >
          {pending ? <Loader2 className="animate-spin" size={16} /> : <X size={16} />}
          Reject
        </button>
      </div>
    </div>
  );
}
