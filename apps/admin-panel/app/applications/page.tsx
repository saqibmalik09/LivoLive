import { CdnImg } from "@/components/CdnImg";
import { supabaseAdmin } from "@/lib/supabase";
import {
  FileText,
  Users,
  CheckCircle2,
  Clock,
  ChevronRight,
  User,
  ShieldCheck,
  Building2,
} from "lucide-react";
import Link from "next/link";
import { format } from "date-fns";
export default async function ApplicationsPage() {
  const { data: agencyApps } = await supabaseAdmin
    .from("user_applications")
    .select("*, users(username, avatar_url)")
    .eq("type", "agency")
    .order("created_at", { ascending: false });
  const stats = {
    pending: agencyApps?.filter((a) => a.status === "pending").length || 0,
    approved: agencyApps?.filter((a) => a.status === "approved").length || 0,
    total: agencyApps?.length || 0,
  };
  return (
    <div className="space-y-10 pb-32">
      <header>
        <span className="text-[10px] font-black uppercase tracking-[0.4em] text-purple-500 mb-1 block">
          Review Center
        </span>
        <h1 className="text-6xl font-black bg-clip-text text-transparent bg-gradient-to-r from-purple-400 via-pink-500 to-red-500 tracking-tighter italic">
          Agency Applications
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Review agency ownership requests. Click any agency to see its host applications.
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="glass-card p-8 border-amber-500/20 bg-amber-500/5">
          <div className="flex items-center justify-between mb-4">
            <Clock className="text-amber-500" size={24} />
            <span className="text-4xl font-black tracking-tighter">{stats.pending}</span>
          </div>
          <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
            Pending Review
          </p>
        </div>
        <div className="glass-card p-8 border-emerald-500/20 bg-emerald-500/5">
          <div className="flex items-center justify-between mb-4">
            <CheckCircle2 className="text-emerald-500" size={24} />
            <span className="text-4xl font-black tracking-tighter">{stats.approved}</span>
          </div>
          <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
            Approved Agencies
          </p>
        </div>
        <div className="glass-card p-8 border-blue-500/20 bg-blue-500/5">
          <div className="flex items-center justify-between mb-4">
            <Building2 className="text-blue-500" size={24} />
            <span className="text-4xl font-black tracking-tighter">{stats.total}</span>
          </div>
          <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
            Total Submissions
          </p>
        </div>
      </div>

      <div className="space-y-4">
        {agencyApps && agencyApps.length > 0 ? (
          agencyApps.map((app) => (
            <Link
              key={app.id}
              href={`/applications/${app.id}`}
              className="glass-card p-6 flex items-center justify-between hover:border-purple-500/30 transition-all group"
            >
              <div className="flex items-center gap-6">
                <div className="w-14 h-14 rounded-2xl bg-purple-500/10 border border-purple-500/20 overflow-hidden flex items-center justify-center">
                  {app.users?.avatar_url ? (
                    <CdnImg src={app.users.avatar_url} className="w-full h-full object-cover" />
                  ) : (
                    <User size={24} className="text-purple-400" />
                  )}
                </div>
                <div>
                  <h3 className="font-bold text-lg">{app.real_name}</h3>
                  <p className="text-xs text-white/40 flex items-center gap-2">
                    <User size={12} /> @{app.users?.username}
                    <span className="text-white/10">•</span>
                    <span className="text-purple-400/60 uppercase text-[10px] font-black tracking-widest">
                      Agency Owner Request
                    </span>
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-8">
                <div className="text-right hidden md:block">
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                    WhatsApp
                  </p>
                  <p className="text-xs font-mono">{app.whatsapp_number}</p>
                </div>
                <div className="text-right hidden md:block">
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                    Submitted
                  </p>
                  <p className="text-xs">{format(new Date(app.created_at), "MMM dd, yyyy")}</p>
                </div>
                <StatusBadge status={app.status} />
                <ChevronRight className="text-white/10 group-hover:text-white transition-colors" />
              </div>
            </Link>
          ))
        ) : (
          <div className="py-20 text-center space-y-4 bg-white/5 rounded-3xl border border-dashed border-white/10">
            <FileText className="mx-auto text-white/10" size={48} />
            <p className="text-white/40 font-medium">No agency applications yet.</p>
          </div>
        )}
      </div>
    </div>
  );
}
function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    pending: "bg-amber-500/20 text-amber-500 border-amber-500/20",
    approved: "bg-emerald-500/20 text-emerald-500 border-emerald-500/20",
    rejected: "bg-red-500/20 text-red-500 border-red-500/20",
  };
  const color = colors[status] || colors.pending;
  return (
    <span
      className={`px-4 py-1.5 rounded-full text-[10px] font-black uppercase tracking-[0.2em] border ${color}`}
    >
      {status}
    </span>
  );
}
