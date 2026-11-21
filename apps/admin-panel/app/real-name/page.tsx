import { CdnImg } from "@/components/CdnImg";
import Link from "next/link";
import { supabaseAdmin } from "@/lib/supabase";
import { ShieldCheck, Clock, CheckCircle2, XCircle, ChevronRight, User } from "lucide-react";
import { format } from "date-fns";
export default async function RealNameListPage() {
  const { data: apps } = await supabaseAdmin
    .from("real_name_applications")
    .select(
      "id, status, legal_name, step1_done, step2_done, step3_done, step4_done, step5_done, deposit_coins, updated_at, users:user_id(username, avatar_url, short_id)",
    )
    .order("updated_at", { ascending: false });
  const list = apps ?? [];
  const stats = {
    pending: list.filter((a) => a.status === "pending").length,
    approved: list.filter((a) => a.status === "approved").length,
    rejected: list.filter((a) => a.status === "rejected").length,
  };
  return (
    <div className="space-y-10 pb-32">
      <header>
        <span className="text-[10px] font-black uppercase tracking-[0.4em] text-sky-400 mb-1 block">
          KYC Review
        </span>
        <h1 className="text-5xl font-black tracking-tighter">Real Name Verification</h1>
        <p className="text-white/60 mt-2">Review identity applications, media, and deposits.</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass-card p-6 border-amber-500/20">
          <div className="flex justify-between items-center">
            <Clock className="text-amber-400" />
            <span className="text-3xl font-black">{stats.pending}</span>
          </div>
          <p className="text-xs text-white/40 mt-2 uppercase tracking-widest">Pending</p>
        </div>
        <div className="glass-card p-6 border-emerald-500/20">
          <div className="flex justify-between items-center">
            <CheckCircle2 className="text-emerald-400" />
            <span className="text-3xl font-black">{stats.approved}</span>
          </div>
          <p className="text-xs text-white/40 mt-2 uppercase tracking-widest">Approved</p>
        </div>
        <div className="glass-card p-6 border-red-500/20">
          <div className="flex justify-between items-center">
            <XCircle className="text-red-400" />
            <span className="text-3xl font-black">{stats.rejected}</span>
          </div>
          <p className="text-xs text-white/40 mt-2 uppercase tracking-widest">Rejected</p>
        </div>
      </div>

      <div className="space-y-3">
        {list.length === 0 && (
          <div className="glass-card p-10 text-center text-white/40">No applications yet.</div>
        )}
        {list.map((app: any) => {
          const user = Array.isArray(app.users) ? app.users[0] : app.users;
          return (
            <Link
              key={app.id}
              href={`/real-name/${app.id}`}
              className="glass-card p-5 flex items-center justify-between hover:border-sky-500/30 transition-all"
            >
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-2xl bg-sky-500/10 overflow-hidden flex items-center justify-center">
                  {user?.avatar_url ? (
                    <CdnImg src={user.avatar_url} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <User className="text-sky-300" size={20} />
                  )}
                </div>
                <div>
                  <p className="font-bold">{app.legal_name || user?.username || "Applicant"}</p>
                  <p className="text-xs text-white/40">
                    @{user?.username} · ID {user?.short_id} ·{" "}
                    {app.updated_at ? format(new Date(app.updated_at), "MMM d, HH:mm") : "—"}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <span
                  className={`text-[10px] font-black uppercase tracking-widest px-2 py-1 rounded-lg ${
                    app.status === "pending"
                      ? "bg-amber-500/20 text-amber-300"
                      : app.status === "approved"
                        ? "bg-emerald-500/20 text-emerald-300"
                        : app.status === "rejected"
                          ? "bg-red-500/20 text-red-300"
                          : "bg-white/10 text-white/50"
                  }`}
                >
                  {app.status}
                </span>
                <ChevronRight className="text-white/30" size={18} />
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
