import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth/require-super-bd';
import { getPortalPermissions, staffRoleLabel } from '@/lib/permissions';
import { UserSearchPicker } from '@/components/UserSearchPicker';

export default async function CreateStaffPage() {
  const { staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);

  if (!permissions.canCreateStaff || permissions.creatableRoles.length === 0) {
    redirect('/');
  }

  const multi = permissions.creatableRoles.length > 1;
  const title = multi
    ? 'Create team member'
    : `Create ${staffRoleLabel(permissions.childRole!)}`;
  const description = multi
    ? 'Search a user by short ID or username, pick a role (Country Admin, BD, Assistant, or Customer Service), then assign them under your network.'
    : `Search a user by short ID or username, then assign them as ${staffRoleLabel(permissions.childRole!)} under your team.`;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-black italic">{title}</h1>
        <p className="text-sm text-white/50 mt-2">{description}</p>
      </div>
      <UserSearchPicker
        childRole={permissions.childRole!}
        creatableRoles={permissions.creatableRoles}
        actionLabel={permissions.createStaffActionLabel ?? 'Create staff'}
      />
    </div>
  );
}
