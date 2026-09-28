import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { ArrowLeft, Network, Plus, Users } from "lucide-react";
const roleLabels: Record<string, string> = {
  super_bd: "Super Admin",
  bd_admin: "BD Admin",
  bd: "BD",
};
export default async function StaffPage() {
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
      users:user_id (id, username, short_id, avatar_url)
    `,
    )
    .order("created_at", { ascending: false });
  const { data: agencies } = await supabaseAdmin.from("agencies").select("id, sponsor_staff_id");
  const agencyCountByStaff = (agencies || []).reduce<Record<string, number>>((acc, row) => {
    if (row.sponsor_staff_id) {
      acc[row.sponsor_staff_id] = (acc[row.sponsor_staff_id] || 0) + 1;
    }
    return acc;
  }, {});
  const childrenCount = (staff || []).reduce<Record<string, number>>((acc, row) => {
    if (row.parent_staff_id) {
      acc[row.parent_staff_id] = (acc[row.parent_staff_id] || 0) + 1;
    }
    return acc;
  }, {});
  return (
    <div className="space-y-10 pb-32">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group mb-2"
          >
            <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
            <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
          </Link>
          <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
            <Network size={48} className="text-amber-400" />
            BD Staff Chain
          </h1>
          <p className="text-white/40 font-medium max-w-xl">
            Official hierarchy: Super Admin → BD Admin → BD → Agencies. Create Super Admin accounts
            here.
          </p>
        </div>
        <Link
          href="/staff/new"
          className="inline-flex items-center gap-2 px-6 py-4 bg-amber-500 hover:bg-amber-400 text-black font-black rounded-2xl transition-all"
        >
          <Plus size={18} />
          Create Super Admin
        </Link>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {(staff || []).map((row: any) => {
          const user = row.users;
          return (
            <Link
              key={row.id}
              href={`/staff/${row.id}`}
              className="glass-card p-8 hover:border-amber-500/30 transition-all block"
            >
              <div className="flex items-start justify-between gap-4 mb-6">
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/80">
                    {roleLabels[row.role] || row.role}
                  </p>
                  <h3 className="text-xl font-black mt-1">{user?.username || "Unknown"}</h3>
                  <p className="text-xs text-white/40">ID: {user?.short_id ?? "—"}</p>
                </div>
                <span
                  className={`text-[10px] font-black uppercase px-3 py-1 rounded-full ${row.is_active ? "bg-emerald-500/20 text-emerald-300" : "bg-red-500/20 text-red-300"}`}
                >
                  {row.is_active ? "Active" : "Inactive"}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-white/30 text-[10px] font-black uppercase">Staff Code</p>
                  <p className="font-bold">{row.staff_code}</p>
                </div>
                <div>
                  <p className="text-white/30 text-[10px] font-black uppercase">Team</p>
                  <p className="font-bold flex items-center gap-1">
                    <Users size={14} />
                    {childrenCount[row.id] || 0}
                  </p>
                </div>
                <div>
                  <p className="text-white/30 text-[10px] font-black uppercase">Agencies</p>
                  <p className="font-bold">{agencyCountByStaff[row.id] || 0}</p>
                </div>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
