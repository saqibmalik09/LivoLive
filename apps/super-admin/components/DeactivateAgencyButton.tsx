'use client';

import { useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { Loader2 } from 'lucide-react';
import { deactivateAgencyMember } from '@/lib/actions';

export function DeactivateAgencyButton({
  agencyId,
  name,
}: {
  agencyId: string;
  name: string;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();

  function onClick() {
    if (!confirm(`Deactivate agency "${name}"? New host joins will be blocked.`)) return;
    start(async () => {
      const res = await deactivateAgencyMember(agencyId);
      if (res.success) {
        toast.success('Agency deactivated');
        router.push('/agencies');
        router.refresh();
      } else {
        toast.error(res.error || 'Failed');
      }
    });
  }

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={pending}
      className="rounded-xl bg-red-500/20 text-red-300 px-4 py-2 text-sm font-bold hover:bg-red-500/30 disabled:opacity-50"
    >
      {pending ? <Loader2 className="inline animate-spin" size={16} /> : null} Deactivate agency
    </button>
  );
}
