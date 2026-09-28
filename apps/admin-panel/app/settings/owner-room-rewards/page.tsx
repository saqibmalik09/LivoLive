import { supabaseAdmin } from "@/lib/supabase";
import { OwnerRoomRewardManager } from "@/components/OwnerRoomRewardManager";
import {
  listShopItemsForOwnerRoomReward,
  type OwnerRoomRewardItemRow,
  type OwnerRoomRewardLevelRow,
} from "@/app/settings/owner-room-rewards/actions";
import { ArrowLeft, Crown } from "lucide-react";
import Link from "next/link";
export default async function OwnerRoomRewardsSettingsPage() {
  const [levelsRes, itemsRes, rulesRes, shopItems] = await Promise.all([
    supabaseAdmin.from("owner_room_reward_levels").select("*").order("level", { ascending: true }),
    supabaseAdmin
      .from("owner_room_reward_items")
      .select("*")
      .order("level", { ascending: true })
      .order("sort_order", { ascending: true }),
    supabaseAdmin.from("owner_room_reward_rules").select("rules").eq("id", 1).maybeSingle(),
    listShopItemsForOwnerRoomReward(),
  ]);
  const levels: OwnerRoomRewardLevelRow[] = (levelsRes.data ?? []).map((r) => ({
    level: Number(r.level),
    required_points: Number(r.required_points),
    is_active: Boolean(r.is_active),
    sort_order: Number(r.sort_order ?? 0),
  }));
  const items = (itemsRes.data ?? []) as OwnerRoomRewardItemRow[];
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
        <div className="w-20 h-20 rounded-3xl bg-sky-500/20 border border-sky-500/20 flex items-center justify-center text-sky-300">
          <Crown size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Owner Profile Rewards</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Room-owner-only gift box on the host profile (and room rail). Same energy / levels /
            2‑minute claim rules as the daily room box — prizes can be coins or timed cosmetics.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Run <code className="text-amber-400">node scripts/apply-owner-room-reward.mjs</code>{" "}
            from sklive-admin.
          </p>
        </div>
      )}

      <OwnerRoomRewardManager levels={levels} items={items} rules={rules} shopItems={shopItems} />
    </div>
  );
}
