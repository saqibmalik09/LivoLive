import { supabaseAdmin } from "@/lib/supabase";
import { MicDailyRewardManager } from "@/components/MicDailyRewardManager";
import {
  listShopItemsForMicDailyReward,
  type MicDailyRewardLevelRow,
} from "@/app/settings/mic-daily-rewards/actions";
import { ArrowLeft, Mic } from "lucide-react";
import Link from "next/link";
export default async function MicDailyRewardsSettingsPage() {
  const [levelsRes, rulesRes, shopItems] = await Promise.all([
    supabaseAdmin
      .from("mic_daily_reward_levels")
      .select("*")
      .order("sort_order", { ascending: true })
      .order("required_seconds", { ascending: true }),
    supabaseAdmin.from("mic_daily_reward_rules").select("rules").eq("id", 1).maybeSingle(),
    listShopItemsForMicDailyReward(),
  ]);
  const levels: MicDailyRewardLevelRow[] = (levelsRes.data ?? []).map((r) => ({
    id: String(r.id),
    required_seconds: Number(r.required_seconds),
    sort_order: Number(r.sort_order ?? 0),
    reward_type: (r.reward_type === "shop_item" ? "shop_item" : "coins") as "coins" | "shop_item",
    coin_amount: Number(r.coin_amount ?? 0),
    shop_item_id: r.shop_item_id ? String(r.shop_item_id) : null,
    duration_days: r.duration_days == null ? null : Number(r.duration_days),
    title: String(r.title ?? ""),
    image_url: String(r.image_url ?? ""),
    is_active: Boolean(r.is_active),
  }));
  const rules = Array.isArray(rulesRes.data?.rules)
    ? (rulesRes.data!.rules as unknown[]).map((r) => String(r))
    : [];
  const error = levelsRes.error || rulesRes.error;
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
        <div className="w-20 h-20 rounded-3xl bg-sky-500/20 border border-sky-500/20 flex items-center justify-center text-sky-300">
          <Mic size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Mic Daily Rewards</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Reward users for sitting unmuted on mic (30m / 1h / …). Coins or shop assets, claimable
            once per UTC+3 day from My Profile.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Run <code className="text-amber-400">node scripts/apply-mic-daily-rewards.mjs</code>{" "}
            from sklive-admin.
          </p>
        </div>
      )}

      <MicDailyRewardManager levels={levels} rules={rules} shopItems={shopItems} />
    </div>
  );
}
