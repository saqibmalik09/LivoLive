import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { StaffDetailActions } from "./StaffDetailActions";
const roleLabels: Record<string, string> = {
  super_bd: "Super Admin",
  bd_admin: "BD Admin",
  bd: "BD",
};
export default async function StaffDetailPage({
  params,
}: {
  params: Promise<{
    id: string;
  }>;
}) {
  const { id } = await params;
  const { data: staff } = await supabaseAdmin
    .from("business_staff")
    .select(
      `
      id,
      role,
      staff_code,
      is_active,
      created_at,
      parent_staff_id,
      users:user_id (id, username, short_id, avatar_url, diamonds)
    `,
    )
    .eq("id", id)
    .single();
  if (!staff) notFound();
  const user = (staff as any).users;
  const { data: children } = await supabaseAdmin
    .from("business_staff")
    .select("id, role, staff_code, is_active, users:user_id(username, short_id)")
    .eq("parent_staff_id", id)
    .order("created_at", { ascending: false });
  const { data: agencies } = await supabaseAdmin
    .from("agencies")
    .select("id, name, agency_code, is_active, created_at")
    .eq("sponsor_staff_id", id)
    .order("created_at", { ascending: false });
  let parent: any = null;
  if (staff.parent_staff_id) {
    const { data } = await supabaseAdmin
      .from("business_staff")
      .select("id, role, users:user_id(username)")
      .eq("id", staff.parent_staff_id)
      .maybeSingle();
    parent = data;
  }
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/staff"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Staff Chain</span>
      </Link>

      <div className="glass-card p-10 space-y-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-amber-400">
              {roleLabels[staff.role] || staff.role}
            </p>
            <h1 className="text-4xl font-black italic">{user?.username}</h1>
            <p className="text-white/40">
              Short ID {user?.short_id} · Code {staff.staff_code}
            </p>
            {parent && (
              <p className="text-sm text-white/50 mt-2">
                Parent: {(parent as any).users?.username} ({roleLabels[parent.role]})
              </p>
            )}
          </div>
          <StaffDetailActions staffId={staff.id} isActive={staff.is_active} />
        </div>
        <p className="text-sm text-white/50">
          Diamonds balance: {user?.diamonds?.toLocaleString() ?? 0}
        </p>
      </div>

      <section className="space-y-4">
        <h2 className="text-xl font-black uppercase tracking-widest text-white/60">Direct Team</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {(children || []).map((child: any) => (
            <Link
              key={child.id}
              href={`/staff/${child.id}`}
              className="glass-card p-6 hover:border-amber-500/20"
            >
              <p className="text-[10px] font-black uppercase text-amber-400/70">
                {roleLabels[child.role]}
              </p>
              <p className="font-bold text-lg">{child.users?.username}</p>
              <p className="text-xs text-white/40">Code {child.staff_code}</p>
            </Link>
          ))}
          {(children || []).length === 0 && (
            <p className="text-white/30 text-sm">No direct reports yet.</p>
          )}
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-black uppercase tracking-widest text-white/60">
          Sponsored Agencies
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {(agencies || []).map((agency: any) => (
            <Link key={agency.id} href={`/agencies/${agency.id}`} className="glass-card p-6">
              <p className="font-bold">{agency.name}</p>
              <p className="text-xs text-white/40">Code {agency.agency_code}</p>
            </Link>
          ))}
          {(agencies || []).length === 0 && (
            <p className="text-white/30 text-sm">No agencies under this staff member.</p>
          )}
        </div>
      </section>
    </div>
  );
}
