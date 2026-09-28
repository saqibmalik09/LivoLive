"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export type TaskWheelTierInput = {
  id?: string | null;
  min_coins: number;
  max_coins: number;
  weight_percent: number;
  label: string;
  sort_order: number;
  is_active: boolean;
};
function revalidate() {
  revalidatePath("/settings/task-wheel");
  revalidatePath("/settings");
}
export async function saveTaskWheelTiers(tiers: TaskWheelTierInput[]) {
  try {
    if (!Array.isArray(tiers) || tiers.length === 0) {
      throw new Error("Add at least one reward tier");
    }
    const cleaned = tiers.map((t, i) => {
      const min = Math.floor(Number(t.min_coins));
      const max = Math.floor(Number(t.max_coins));
      const pct = Number(t.weight_percent);
      if (!Number.isFinite(min) || min < 0) throw new Error(`Tier ${i + 1}: invalid min`);
      if (!Number.isFinite(max) || max < min) {
        throw new Error(`Tier ${i + 1}: max must be >= min`);
      }
      if (!Number.isFinite(pct) || pct <= 0) {
        throw new Error(`Tier ${i + 1}: percent must be > 0`);
      }
      return {
        id: t.id && String(t.id).trim() ? String(t.id) : undefined,
        min_coins: min,
        max_coins: max,
        weight_percent: Math.round(pct * 100) / 100,
        label: (t.label || `${min}-${max}`).trim().slice(0, 40),
        sort_order: Number.isFinite(Number(t.sort_order))
          ? Math.floor(Number(t.sort_order))
          : i + 1,
        is_active: t.is_active !== false,
      };
    });
    const activePct = cleaned.filter((t) => t.is_active).reduce((s, t) => s + t.weight_percent, 0);
    if (activePct <= 0) throw new Error("Active tiers must have total percent > 0");
    if (Math.abs(activePct - 100) > 0.5) {
      throw new Error(`Active tier percents must total ~100% (currently ${activePct.toFixed(2)}%)`);
    }
    const { error: delErr } = await supabaseAdmin
      .from("task_wheel_tiers")
      .delete()
      .neq("id", "00000000-0000-0000-0000-000000000000");
    if (delErr) throw delErr;
    const { error: insErr } = await supabaseAdmin
      .from("task_wheel_tiers")
      .insert(cleaned.map(({ id: _id, ...row }) => row));
    if (insErr) throw insErr;
    await logAdminAction({
      action: "settings.task_wheel_tiers",
      targetType: "task_wheel_tiers",
      summary: `Updated task wheel tiers (${cleaned.length} rows, ${activePct}% total)`,
      metadata: { tiers: cleaned },
    });
    revalidate();
    return { success: true };
  } catch (error: any) {
    console.error("saveTaskWheelTiers", error);
    return { success: false, error: error.message ?? "Save failed" };
  }
}
