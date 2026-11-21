import { CdnImg } from "@/components/CdnImg";
import { supabaseAdmin } from "@/lib/supabase";
import {
  ArrowLeft,
  User,
  MessageSquare,
  CheckCircle2,
  Calendar,
  ShieldCheck,
  Users,
  ChevronRight,
} from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { format } from "date-fns";
import { ApplicationActions } from "../ApplicationActions";
interface AgencyAppPageProps {
  params: Promise<{
    id: string;
  }>;
}
export default async function AgencyAppPage({ params }: AgencyAppPageProps) {
  const { id } = await params;
  const { data: app, error } = await supabaseAdmin
    .from("user_applications")
    .select("*, users(*)")
    .eq("id", id)
    .single();
  if (error || !app) {
    notFound();
  }
  let agency = null;
  let hostApplications: any[] = [];
  if (app.status === "approved") {
    const { data: agencyData } = await supabaseAdmin
      .from("agencies")
      .select("*")
      .eq("owner_id", app.user_id)
      .maybeSingle();
    agency = agencyData;
    if (agency) {
      const { data: hostApps } = await supabaseAdmin
        .from("agency_applications")
        .select("*, users(username, avatar_url, coins, wealth_level, user_level, created_at)")
        .eq("agency_id", agency.id)
        .order("created_at", { ascending: false });
      hostApplications = hostApps || [];
    }
  }
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/applications"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Applications</span>
      </Link>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
        <div className="lg:col-span-1 space-y-8">
          <div className="glass-card p-10 text-center">
            <div className="w-32 h-32 rounded-full border-4 border-purple-500/30 p-1 mx-auto mb-6 relative">
              <div className="w-full h-full rounded-full overflow-hidden bg-white/5 border border-white/10">
                {app.users?.avatar_url ? (
                  <CdnImg src={app.users.avatar_url} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-purple-400">
                    <User size={48} />
                  </div>
                )}
              </div>
              <div className="absolute -bottom-2 -right-2 bg-purple-600 border-4 border-black p-2 rounded-xl">
                <ShieldCheck size={20} className="text-white" />
              </div>
            </div>

            <h2 className="text-3xl font-black tracking-tight">{app.users?.username}</h2>
            <p className="text-white/40 font-mono text-xs mt-1">
              ID: {app.users?.id?.substring(0, 12)}...
            </p>

            <div className="grid grid-cols-2 gap-4 mt-10">
              <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                  Coins
                </p>
                <p className="font-bold text-amber-500">{app.users?.coins?.toLocaleString()}</p>
              </div>
              <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                  Wealth
                </p>
                <p className="font-bold text-emerald-500">Lv.{app.users?.wealth_level}</p>
              </div>
            </div>
          </div>

          <div className="glass-card p-10 space-y-6">
            <h3 className="text-xs font-black uppercase tracking-[0.3em] text-white/20 border-b border-white/5 pb-4">
              Contact Information
            </h3>
            <div className="space-y-4">
              <div className="flex items-center gap-4">
                <div className="w-10 h-10 rounded-xl bg-green-500/10 flex items-center justify-center text-green-500">
                  <MessageSquare size={18} />
                </div>
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20">
                    WhatsApp
                  </p>
                  <p className="text-sm font-bold">{app.whatsapp_number}</p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-500">
                  <Calendar size={18} />
                </div>
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20">
                    Submitted On
                  </p>
                  <p className="text-sm font-bold">
                    {format(new Date(app.created_at), "MMMM dd, yyyy")}
                  </p>
                </div>
              </div>
            </div>
          </div>

          {agency && (
            <div className="glass-card p-10 space-y-6 border-purple-500/20 bg-purple-500/5">
              <h3 className="text-xs font-black uppercase tracking-[0.3em] text-purple-400 border-b border-purple-500/10 pb-4">
                Agency Created
              </h3>
              <div className="space-y-4">
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                    Agency Name
                  </p>
                  <p className="text-lg font-black">{agency.name}</p>
                </div>
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                    Invitation Code
                  </p>
                  <p className="text-2xl font-black font-mono text-purple-400 tracking-[0.3em]">
                    {agency.agency_code}
                  </p>
                </div>
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                    Status
                  </p>
                  <span
                    className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest border ${agency.is_active ? "bg-emerald-500/20 text-emerald-500 border-emerald-500/20" : "bg-red-500/20 text-red-500 border-red-500/20"}`}
                  >
                    {agency.is_active ? "Active" : "Inactive"}
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="lg:col-span-2 space-y-8">
          <div className="glass-card p-12 space-y-12">
            <header className="flex items-center justify-between">
              <div>
                <span className="bg-purple-500/20 text-purple-400 px-4 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest border border-purple-500/20 mb-4 inline-block">
                  Agency Application
                </span>
                <h1 className="text-5xl font-black tracking-tighter italic">
                  Reviewing <span className="text-white/20">{app.real_name}</span>
                </h1>
              </div>
              <div className="text-right">
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                  Status
                </p>
                <StatusBadge status={app.status} />
              </div>
            </header>

            <div className="p-8 bg-white/5 border border-white/5 rounded-3xl space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-2">
                    Legal Name
                  </p>
                  <p className="text-xl font-bold">{app.real_name}</p>
                </div>
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-2">
                    Platform Handle
                  </p>
                  <p className="text-xl font-bold text-purple-400">@{app.users?.username}</p>
                </div>
              </div>
            </div>

            <div className="pt-8 border-t border-white/5">
              <ApplicationActions id={app.id} status={app.status} type="agency" />
            </div>
          </div>

          <div className="glass-card p-10 border-blue-500/20 bg-blue-500/5">
            <div className="flex gap-4">
              <div className="w-12 h-12 rounded-2xl bg-blue-500/20 flex items-center justify-center text-blue-400 shrink-0">
                <CheckCircle2 size={24} />
              </div>
              <div>
                <h4 className="font-black uppercase tracking-widest text-xs mb-2 text-blue-400">
                  Approval Impact
                </h4>
                <p className="text-sm text-blue-200/60 leading-relaxed">
                  Upon approval, a new Agency record will be generated with a unique 6-digit
                  invitation code. The user will be able to start recruiting hosts immediately using
                  this code.
                </p>
              </div>
            </div>
          </div>

          {agency && (
            <div className="glass-card p-10 space-y-8">
              <div className="flex items-center justify-between">
                <h3 className="text-xl font-black flex items-center gap-3">
                  <Users className="text-pink-500" size={24} />
                  Host Applications
                  <span className="text-[10px] font-black uppercase tracking-widest bg-pink-500/20 text-pink-400 px-3 py-1 rounded-full border border-pink-500/20">
                    {hostApplications.length}
                  </span>
                </h3>
              </div>

              {hostApplications.length > 0 ? (
                <div className="space-y-4">
                  {hostApplications.map((host) => (
                    <HostCard key={host.id} host={host} />
                  ))}
                </div>
              ) : (
                <div className="py-12 text-center space-y-3 bg-white/5 rounded-2xl border border-dashed border-white/10">
                  <Users className="mx-auto text-white/10" size={36} />
                  <p className="text-white/30 text-sm font-medium">
                    No host applications for this agency yet.
                  </p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
function HostCard({ host }: { host: any }) {
  return (
    <div className="p-6 bg-white/5 border border-white/5 rounded-2xl flex items-center justify-between hover:border-pink-500/20 transition-all group">
      <div className="flex items-center gap-5">
        <div className="w-12 h-12 rounded-full bg-white/5 overflow-hidden border border-white/10">
          {host.users?.avatar_url ? (
            <CdnImg src={host.users.avatar_url} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-pink-400">
              <User size={20} />
            </div>
          )}
        </div>
        <div>
          <h4 className="font-bold">@{host.users?.username}</h4>
          <div className="flex items-center gap-3 mt-1">
            <span className="text-[10px] font-black uppercase tracking-widest text-white/20">
              Lv.{host.users?.user_level}
            </span>
            <span className="text-white/10">•</span>
            <span className="text-[10px] font-mono text-white/20">
              {format(new Date(host.created_at), "MMM dd, yyyy")}
            </span>
          </div>
        </div>
      </div>
      <div className="flex items-center gap-4">
        <div className="text-right hidden md:block">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
            Coins
          </p>
          <p className="text-sm font-bold text-amber-500">{host.users?.coins?.toLocaleString()}</p>
        </div>
        <HostStatusBadge status={host.status} />
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
      className={`px-6 py-2 rounded-full text-xs font-black uppercase tracking-[0.2em] border ${color}`}
    >
      {status}
    </span>
  );
}
function HostStatusBadge({ status }: { status: string }) {
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
