import Link from "next/link";
import { ArrowLeft, Coins } from "lucide-react";
import { CoinSellerPolicyManager } from "@/components/CoinSellerPolicyManager";
import {
  getCoinSellerSettings,
  listCoinSellerRewards,
  listCoinSellerTiers,
  listRecentCoinSellerPurchases,
  listVipPlansForSeller,
} from "./actions";
export default async function CoinSellerPolicyPage() {
  const [settings, tiers, rewards, vipPlans, purchases] = await Promise.all([
    getCoinSellerSettings(),
    listCoinSellerTiers(),
    listCoinSellerRewards(),
    listVipPlansForSeller(),
    listRecentCoinSellerPurchases(),
  ]);
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors"
      >
        <ArrowLeft size={18} />
        <span className="text-xs font-bold uppercase tracking-widest">Back</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-300">
          <Coins size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Coin Seller Policy</h1>
          <p className="text-white/60 mt-2 max-w-2xl">
            Configure USD tiers, coin ratios, and VIP / frame / entrance rewards — then fulfill
            offline seller purchases (credits reseller stock).
          </p>
        </div>
      </header>

      <CoinSellerPolicyManager
        settings={settings}
        tiers={tiers as any}
        rewards={rewards}
        vipPlans={vipPlans as any}
        purchases={purchases as any}
      />
    </div>
  );
}
