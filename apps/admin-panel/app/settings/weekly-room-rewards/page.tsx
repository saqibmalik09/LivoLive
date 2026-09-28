import { supabaseAdmin } from "@/lib/supabase";
import { WeeklyRoomRewardManager } from "@/components/WeeklyRoomRewardManager";
import {
  listShopItemsForWeeklyRoomReward,
  type WeeklyRoomRewardLevelRow,
} from "@/app/settings/weekly-room-rewards/actions";
import { ArrowLeft, Gift } from "lucide-react";
import Link from "next/link";
export default async function WeeklyRoomRewardsSettingsPage() {
  const [levelsRes, rulesRes, shopItems] = await Promise.all([
    supabaseAdmin.from("weekly_room_reward_levels").select("*").order("level", { ascending: true }),
    supabaseAdmin.from("weekly_room_reward_rules").select("rules").eq("id", 1).maybeSingle(),
    listShopItemsForWeeklyRoomReward(),
  ]);
  const levels: WeeklyRoomRewardLevelRow[] = (levelsRes.data ?? []).map((r) => ({
    level: Number(r.level),
    required_points: Number(r.required_points),
    coin_reward: Number(r.coin_reward ?? 0),
    reward_type: (r.reward_type === "shop_item" ? "shop_item" : "coins") as "coins" | "shop_item",
    shop_item_id: r.shop_item_id ? String(r.shop_item_id) : null,
    duration_days: r.duration_days == null ? null : Number(r.duration_days),
    title: String(r.title ?? ""),
    image_url: String(r.image_url ?? ""),
    is_active: Boolean(r.is_active),
    sort_order: Number(r.sort_order ?? 0),
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
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-300">
          <Gift size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Room Reward</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Weekly owner Room Reward: set Room Target tiers with coin or shop-asset prizes. Powers
            My Profile “Room Reward” page and the room float cup.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Run{" "}
            <code className="text-amber-400">node scripts/apply-weekly-room-reward-assets.mjs</code>{" "}
            from sklive-admin.
          </p>
        </div>
      )}

      <WeeklyRoomRewardManager levels={levels} rules={rules} shopItems={shopItems} />
    </div>
  );
}
