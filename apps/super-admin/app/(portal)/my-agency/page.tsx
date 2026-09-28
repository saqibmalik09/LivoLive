import { fetchHierarchy } from '@/lib/auth/require-super-bd';
import { MyAgencyPanel } from '@/components/MyAgencyPanel';
import { CreateAgencyForUserPanel } from '@/components/CreateAgencyForUserPanel';
import type { HierarchyResponse } from '@/lib/types';

export default async function MyAgencyPage() {
  const data = (await fetchHierarchy()) as HierarchyResponse;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-black italic">My agency</h1>
        <p className="text-sm text-white/50 mt-2">
          Your personal agency, or create a new agency for a user under a BD
        </p>
      </div>
      <CreateAgencyForUserPanel />
      <MyAgencyPanel agencies={data.tree.agencies} ownerId={data.me.user_id} />
    </div>
  );
}
