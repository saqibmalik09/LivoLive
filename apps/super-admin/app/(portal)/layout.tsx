import { requireSuperBd } from '@/lib/auth/require-super-bd';
import { Sidebar, MobileHeader, MobileBottomNav } from '@/components/PortalNav';

export default async function PortalLayout({ children }: { children: React.ReactNode }) {
  const { staff, supabase } = await requireSuperBd();
  const { data: profile } = await supabase
    .from('users')
    .select('username')
    .eq('id', staff.user_id)
    .single();

  const username = profile?.username || 'Staff';

  return (
    <div className="min-h-screen pb-20 lg:pb-0">
      <Sidebar username={username} staffCode={staff.staff_code} role={staff.role} />
      <MobileHeader username={username} role={staff.role} />
      <main className="lg:pl-64">
        <div className="max-w-6xl mx-auto px-4 py-6 lg:py-10">{children}</div>
      </main>
      <MobileBottomNav role={staff.role} />
    </div>
  );
}
