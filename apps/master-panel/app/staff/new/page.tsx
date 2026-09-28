import { supabaseAdmin } from '@/lib/supabase';
import NewStaffForm from './NewStaffForm';

export default async function NewStaffPage() {
  const { data: rows } = await supabaseAdmin
    .from('business_staff')
    .select('id, staff_code, user:user_id(username, short_id)')
    .eq('role', 'super_bd')
    .eq('is_active', true)
    .order('created_at', { ascending: false });

  const superBdOptions = (rows ?? []).map((row: any) => {
    const u = Array.isArray(row.user) ? row.user[0] : row.user;
    return {
      id: String(row.id),
      staff_code: String(row.staff_code ?? ''),
      username: u?.username ? String(u.username) : 'Super Admin',
      short_id: u?.short_id != null ? String(u.short_id) : null,
    };
  });

  return <NewStaffForm superBdOptions={superBdOptions} />;
}
