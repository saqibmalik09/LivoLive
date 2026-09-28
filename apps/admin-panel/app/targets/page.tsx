import { supabaseAdmin } from "@/lib/supabase";
import { TargetManagement } from "./TargetManagement";
import { Target, ArrowLeft } from "lucide-react";
import Link from "next/link";
export default async function TargetsPage() {
  const { data: commission } = await supabaseAdmin
    .from("commission_configs")
    .select("*")
    .eq("id", 1)
    .single();
  const { data: salaryTiers } = await supabaseAdmin
    .from("salary_tiers")
    .select("*")
    .order("sort_order", { ascending: true })
    .order("diamonds_target", { ascending: true });
  const { data: salaryChain } = await supabaseAdmin
    .from("salary_chain_configs")
    .select("*")
    .eq("id", 1)
    .maybeSingle();
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
            <Target size={48} className="text-purple-500" />
            Targets & Salary
          </h1>
          <p className="text-white/40 font-medium max-w-xl">
            Configure global revenue sharing percentages and define performance-based salary tiers
            for hosts.
          </p>
        </div>
      </div>

      <TargetManagement
        commission={commission}
        salaryTiers={salaryTiers || []}
        salaryChain={salaryChain}
      />
    </div>
  );
}
