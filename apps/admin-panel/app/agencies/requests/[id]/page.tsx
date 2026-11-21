import { CdnImg } from "@/components/CdnImg";
import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft, User, MessageSquare, CheckCircle2, Calendar, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { format } from "date-fns";
import { RequestActions } from "./RequestActions";
interface RequestDetailProps {
  params: Promise<{
    id: string;
  }>;
}
export default async function RequestDetailPage({ params }: RequestDetailProps) {
  const { id } = await params;
  const { data: app, error } = await supabaseAdmin
    .from("user_applications")
    .select("*, users(*)")
    .eq("id", id)
    .single();
  if (error || !app) notFound();
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/applications"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Requests</span>
      </Link>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
        <div className="lg:col-span-1 space-y-8">
          <div className="glass-card p-10 text-center">
            <div className="w-32 h-32 rounded-full border-4 border-amber-500/30 p-1 mx-auto mb-6 relative">
              <div className="w-full h-full rounded-full overflow-hidden bg-white/5 border border-white/10">
                {app.users?.avatar_url ? (
                  <CdnImg src={app.users.avatar_url} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-amber-400">
                    <User size={48} />
                  </div>
                )}
              </div>
              <div className="absolute -bottom-2 -right-2 bg-amber-600 border-4 border-black p-2 rounded-xl">
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
              Contact
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
                    Submitted
                  </p>
                  <p className="text-sm font-bold">
                    {format(new Date(app.created_at), "MMMM dd, yyyy")}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 space-y-8">
          <div className="glass-card p-12 space-y-12">
            <header className="flex items-center justify-between">
              <div>
                <span className="bg-amber-500/20 text-amber-400 px-4 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest border border-amber-500/20 mb-4 inline-block">
                  Agency Ownership Request
                </span>
                <h1 className="text-5xl font-black tracking-tighter italic">{app.real_name}</h1>
              </div>
              <StatusBadge status={app.status} />
            </header>

            <div className="p-8 bg-white/5 border border-white/5 rounded-3xl">
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
              <RequestActions
                id={app.id}
                status={app.status}
                userId={app.user_id}
                realName={app.real_name}
              />
            </div>
          </div>

          <div className="glass-card p-10 border-blue-500/20 bg-blue-500/5">
            <div className="flex gap-4">
              <div className="w-12 h-12 rounded-2xl bg-blue-500/20 flex items-center justify-center text-blue-400 shrink-0">
                <CheckCircle2 size={24} />
              </div>
              <div>
                <h4 className="font-black uppercase tracking-widest text-xs mb-2 text-blue-400">
                  What happens on approval?
                </h4>
                <p className="text-sm text-blue-200/60 leading-relaxed">
                  A new Agency will be created automatically with a unique 6-digit code. The user
                  will become the Agency Owner and can start inviting hosts using their code.
                </p>
              </div>
            </div>
          </div>
        </div>
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
