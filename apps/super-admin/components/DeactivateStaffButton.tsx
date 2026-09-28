'use client';

import { useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { Loader2 } from 'lucide-react';
import { deactivateStaffMember } from '@/lib/actions';

export function DeactivateStaffButton({
  staffId,
  label,
}: {
  staffId: string;
  label: string;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();

  function onClick() {
    if (!confirm(`Remove ${label}? They will be deactivated (soft remove).`)) return;
    start(async () => {
      const res = await deactivateStaffMember(staffId);
      if (res.success) {
        toast.success('Staff removed');
        router.push('/team');
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
      {pending ? <Loader2 className="inline animate-spin" size={16} /> : null} Remove staff
    </button>
  );
}
