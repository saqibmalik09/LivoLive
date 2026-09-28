'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { Building2, Loader2 } from 'lucide-react';
import { createAgencyForOwnerUnderBd } from '@/lib/actions';

export function CreateAgencyForUserPanel() {
  const router = useRouter();
  const [ownerId, setOwnerId] = useState('');
  const [bdId, setBdId] = useState('');
  const [pending, startTransition] = useTransition();

  function onCreate() {
    startTransition(async () => {
      const res = await createAgencyForOwnerUnderBd(ownerId, bdId);
      if (res.success) {
        toast.success(
          res.created
            ? `Agency created. Code: ${res.agency_code}`
            : res.message || `Agency under BD. Code: ${res.agency_code}`,
        );
        setOwnerId('');
        setBdId('');
        router.refresh();
      } else {
        toast.error(res.error || 'Failed');
      }
    });
  }

  return (
    <div className="glass-card p-6 md:p-8 space-y-5">
      <div>
        <h2 className="text-lg font-black flex items-center gap-2">
          <Building2 className="text-emerald-400" size={22} />
          Create agency for user
        </h2>
        <p className="text-sm text-white/50 mt-1">
          Creates a <span className="text-white/70">new</span> agency for a User ID under your BD.
          Cannot attach or move someone else&apos;s agency.
        </p>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div>
          <label className="text-xs text-white/40 mb-1.5 block">Owner User ID</label>
          <input
            value={ownerId}
            onChange={(e) => setOwnerId(e.target.value.replace(/\D/g, ''))}
            className="input-field"
            placeholder="e.g. 100022"
            inputMode="numeric"
          />
        </div>
        <div>
          <label className="text-xs text-white/40 mb-1.5 block">BD ID (staff code)</label>
          <input
            value={bdId}
            onChange={(e) => setBdId(e.target.value.trim())}
            className="input-field"
            placeholder="e.g. 633679"
          />
        </div>
      </div>
      <button
        type="button"
        onClick={onCreate}
        disabled={pending || !ownerId.trim() || !bdId.trim()}
        className="btn-primary inline-flex items-center gap-2"
      >
        {pending ? <Loader2 className="animate-spin" size={18} /> : <Building2 size={18} />}
        Create Agency
      </button>
    </div>
  );
}
