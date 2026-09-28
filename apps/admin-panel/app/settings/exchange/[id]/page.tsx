import { supabaseAdmin } from "@/lib/supabase";
import { ExchangeEditForm } from "@/components/ExchangeEditForm";
import { ArrowLeft, ArrowRightLeft } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
interface ExchangeEditPageProps {
  params: Promise<{
    id: string;
  }>;
}
export default async function ExchangeEditPage({ params }: ExchangeEditPageProps) {
  const { id } = await params;
  const { data: config, error } = await supabaseAdmin
    .from("exchange_configs")
    .select("*")
    .eq("id", id)
    .single();
  if (error || !config) {
    notFound();
  }
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings/exchange"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Exchange Rates</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-emerald-500/20 border border-emerald-500/20 flex items-center justify-center text-emerald-500 shadow-2xl shadow-emerald-500/10">
          <ArrowRightLeft size={40} />
        </div>
        <div>
          <span className="text-[10px] font-black uppercase tracking-[0.4em] text-emerald-500/60 mb-1 block">
            Conversion Settings
          </span>
          <h1 className="text-5xl font-black tracking-tighter uppercase italic">
            {config.from_currency} <span className="text-white/20">/</span> {config.to_currency}
          </h1>
        </div>
      </header>

      <ExchangeEditForm config={config} />
    </div>
  );
}
