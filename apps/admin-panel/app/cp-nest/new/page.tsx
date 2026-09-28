import { CPNestItemForm } from "@/components/CPNestItemForm";
import { ArrowLeft, Heart } from "lucide-react";
import Link from "next/link";
export default function NewCPNestItemPage() {
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/cp-nest"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to CP Nest</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-pink-500/20 border border-pink-500/20 flex items-center justify-center text-pink-500 shadow-2xl shadow-pink-500/10">
          <Heart size={40} />
        </div>
        <div>
          <span className="text-[10px] font-black uppercase tracking-[0.4em] text-pink-500/60 mb-1 block">
            New proposal gift
          </span>
          <h1 className="text-5xl font-black tracking-tighter uppercase italic">
            CP <span className="text-white/20">Nest</span> item
          </h1>
        </div>
      </header>

      <CPNestItemForm />
    </div>
  );
}
