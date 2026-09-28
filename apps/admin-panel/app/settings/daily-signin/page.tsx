import { ArrowLeft, CalendarCheck } from "lucide-react";
import Link from "next/link";
import { DailySignInRewardsManager } from "@/components/DailySignInRewardsManager";
import {
  listDailySignInRewardsAdmin,
  listShopItemsForDailySignIn,
} from "@/app/settings/daily-signin/actions";
export default async function DailySignInSettingsPage() {
  const [rewardsRes, shopItems] = await Promise.all([
    listDailySignInRewardsAdmin(),
    listShopItemsForDailySignIn(),
  ]);
  const byDay = new Map(rewardsRes.rows.map((r) => [r.day_number, r]));
  const rows = Array.from({ length: 7 }, (_, i) => {
    const day = i + 1;
    return (
      byDay.get(day) ?? {
        day_number: day,
        reward_type: "coins" as const,
        coin_amount: 1000,
        shop_item_id: null,
        image_url: null,
        label: `Day ${day}`,
        is_active: true,
      }
    );
  });
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
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-300">
          <CalendarCheck size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Daily Sign-in</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Configure Day 1–7 rewards (coins or shop assets). The mobile popup reads these live from
            the database.
          </p>
        </div>
      </header>

      {!rewardsRes.success && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{rewardsRes.error}</p>
          <p className="mt-3 text-white/50">
            Apply migration <code>20260807150000_daily_signin_rewards.sql</code> first.
          </p>
        </div>
      )}

      <DailySignInRewardsManager rows={rows} shopItems={shopItems} />
    </div>
  );
}
