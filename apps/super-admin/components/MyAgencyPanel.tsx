'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { Building2, Loader2 } from 'lucide-react';
import type { AgencyNode } from '@/lib/types';
import { createOwnAgency } from '@/lib/actions';
import Link from 'next/link';

export function MyAgencyPanel({ agencies, ownerId }: { agencies: AgencyNode[]; ownerId: string }) {
  const router = useRouter();
  const own = agencies.filter((a) => a.owner_id === ownerId);
  const [name, setName] = useState('My Agency');
  const [pending, startTransition] = useTransition();

  function onCreate() {
    startTransition(async () => {
      const res = await createOwnAgency(name);
      if (res.success) {
        toast.success(`Agency created. Code: ${res.agency_code}`);
        router.refresh();
      } else {
        toast.error(res.error || 'Failed');
      }
    });
  }

  if (own.length > 0) {
    const agency = own[0];
    return (
      <div className="glass-card p-6 md:p-8 space-y-4">
        <div className="flex items-center gap-3">
          <Building2 className="text-emerald-400" size={28} />
          <div>
            <h2 className="text-xl font-black">{agency.name}</h2>
            <p className="text-sm text-white/50">Code: {agency.agency_code}</p>
          </div>
        </div>
        <p className="text-sm text-white/60">{agency.host_count} hosts in this agency</p>
        <Link href={`/agencies/${agency.id}`} className="btn-primary inline-flex">
          View agency details
        </Link>
      </div>
    );
  }

  return (
    <div className="glass-card p-6 md:p-8 space-y-6">
      <div>
        <h2 className="text-lg font-black">Create your agency</h2>
        <p className="text-sm text-white/50 mt-1">
          Your personal agency only. To create for another user, use the form above (User ID + BD).
        </p>
      </div>
      <input
        value={name}
        onChange={(e) => setName(e.target.value)}
        className="input-field"
        placeholder="Agency name"
      />
      <button type="button" onClick={onCreate} disabled={pending || !name.trim()} className="btn-primary">
        {pending ? <Loader2 className="animate-spin" size={18} /> : <Building2 size={18} />}
        Create Agency
      </button>
    </div>
  );
}
