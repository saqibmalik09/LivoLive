import { ArrowLeft, Gift } from "lucide-react";
import Link from "next/link";
import { LuckyBagSettingsForm } from "@/components/LuckyBagSettingsForm";
import { getLuckyBagRules, listLuckyBagTiers } from "@/lib/actions/lucky-bags";
export default async function LuckyBagsSettingsPage() {
  const [tiers, rules] = await Promise.all([listLuckyBagTiers(), getLuckyBagRules()]);
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-pink-500/20 border border-pink-500/20 flex items-center justify-center text-pink-400">
          <Gift size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Lucky Bags</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Configure coin tiers, recipient counts, and in-app rules for Room and World lucky bags.
          </p>
        </div>
      </header>

      <LuckyBagSettingsForm initialTiers={tiers} initialRules={rules} />
    </div>
  );
}
