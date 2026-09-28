import { supabaseAdmin } from "@/lib/supabase";
import { VipEditForm } from "@/components/VipEditForm";
import { ArrowLeft, Crown } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
interface VipEditPageProps {
  params: Promise<{
    id: string;
  }>;
}
export default async function VipEditPage({ params }: VipEditPageProps) {
  const { id } = await params;
  const { data: plan, error } = await supabaseAdmin
    .from("vip_plans")
    .select("*")
    .eq("id", id)
    .single();
  if (error || !plan) {
    notFound();
  }
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings/vip"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to VIP Tiers</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-500 shadow-2xl shadow-amber-500/10">
          <Crown size={40} />
        </div>
        <div>
          <span className="text-[10px] font-black uppercase tracking-[0.4em] text-amber-500/60 mb-1 block">
            Level {plan.level} Configuration
          </span>
          <h1 className="text-5xl font-black tracking-tighter">{plan.name}</h1>
        </div>
      </header>

      <VipEditForm plan={plan} />
    </div>
  );
}
