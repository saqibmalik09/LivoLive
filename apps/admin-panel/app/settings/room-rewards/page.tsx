import { supabaseAdmin } from "@/lib/supabase";
import { RoomRewardManager } from "@/components/RoomRewardManager";
import {
  listShopItemsForRoomReward,
  type RoomRewardItemRow,
  type RoomRewardLevelRow,
} from "@/app/settings/room-rewards/actions";
import { ArrowLeft, Gift } from "lucide-react";
import Link from "next/link";
export default async function RoomRewardsSettingsPage() {
  const [levelsRes, itemsRes, rulesRes, shopItems] = await Promise.all([
    supabaseAdmin.from("room_reward_levels").select("*").order("level", { ascending: true }),
    supabaseAdmin
      .from("room_reward_items")
      .select("*")
      .order("level", { ascending: true })
      .order("sort_order", { ascending: true }),
    supabaseAdmin.from("room_reward_rules").select("rules").eq("id", 1).maybeSingle(),
    listShopItemsForRoomReward(),
  ]);
  const levels: RoomRewardLevelRow[] = (levelsRes.data ?? []).map((r) => ({
    level: Number(r.level),
    required_points: Number(r.required_points),
    is_active: Boolean(r.is_active),
    sort_order: Number(r.sort_order ?? 0),
  }));
  const items = (itemsRes.data ?? []) as RoomRewardItemRow[];
  const rules = Array.isArray(rulesRes.data?.rules)
    ? (rulesRes.data!.rules as unknown[]).map((r) => String(r))
    : [];
  const error = levelsRes.error || itemsRes.error || rulesRes.error;
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
        <div className="w-20 h-20 rounded-3xl bg-violet-500/20 border border-violet-500/20 flex items-center justify-center text-violet-300">
          <Gift size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Room Reward Gift Box</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Configure Lv1–Lv5 point thresholds, reward pools, and rules for the live-room gift box
            float button.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Run <code className="text-amber-400">node scripts/apply-room-reward-migration.mjs</code>{" "}
            from sk-live-admin.
          </p>
        </div>
      )}

      <RoomRewardManager levels={levels} items={items} rules={rules} shopItems={shopItems} />
    </div>
  );
}
