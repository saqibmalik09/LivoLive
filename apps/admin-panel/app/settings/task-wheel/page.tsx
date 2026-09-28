import { supabaseAdmin } from "@/lib/supabase";
import { TaskWheelConfigClient } from "./TaskWheelConfigClient";
import { ArrowLeft, Dices } from "lucide-react";
import Link from "next/link";
export default async function TaskWheelSettingsPage() {
  const { data } = await supabaseAdmin
    .from("task_wheel_tiers")
    .select("id, min_coins, max_coins, weight_percent, label, sort_order, is_active")
    .order("sort_order", { ascending: true });
  const tiers = (data ?? []).map((row) => ({
    id: String(row.id),
    min_coins: Number(row.min_coins ?? 0),
    max_coins: Number(row.max_coins ?? 0),
    weight_percent: Number(row.weight_percent ?? 0),
    label: String(row.label ?? ""),
    sort_order: Number(row.sort_order ?? 0),
    is_active: row.is_active !== false,
  }));
  return (
    <div className="space-y-8 pb-24">
      <div className="flex items-center gap-4">
        <Link
          href="/settings"
          className="p-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10"
        >
          <ArrowLeft size={18} />
        </Link>
        <div>
          <h1 className="text-3xl font-black flex items-center gap-3 tracking-tight">
            <Dices className="text-amber-400" />
            Task Check-in Wheel
          </h1>
          <p className="text-white/50 text-sm mt-1">
            Set coin ranges (e.g. 100–5000) and win percentages for the daily task prize wheel.
          </p>
        </div>
      </div>

      <TaskWheelConfigClient initialTiers={tiers} />
    </div>
  );
}
