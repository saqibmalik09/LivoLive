import { fetchApplications, requireStaff } from '@/lib/auth/require-super-bd';
import { getPortalPermissions } from '@/lib/permissions';
import { ApplicationCard } from '@/components/ApplicationCard';

export default async function ApplicationsPage() {
  const { staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  const apps = await fetchApplications();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-black italic">Agency requests</h1>
        <p className="text-sm text-white/50 mt-2">
          {permissions.applicationsScope === 'subtree'
            ? 'Pending applications for you and your entire downline'
            : 'Pending applications assigned to you and your network'}
        </p>
      </div>

      {apps.length === 0 ? (
        <div className="glass-card p-10 text-center text-white/40">No pending requests.</div>
      ) : (
        <div className="space-y-4">
          {apps.map((app) => (
            <ApplicationCard key={app.id} app={app} />
          ))}
        </div>
      )}
    </div>
  );
}
