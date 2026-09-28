"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export type GiftBonusConfigInput = {
  receiver_percent: number;
  gifts_for_bonus_min: number;
  gifts_for_bonus_max: number;
  bonus_multiplier_min: number;
  bonus_multiplier_max: number;
  bonus_chance_percent: number;
  bonus_trigger_mode: "same_receiver" | "random" | "both";
};
async function upsertGiftBonusConfig(
  table: "lucky_gift_config" | "lucky_pro_gift_config",
  data: GiftBonusConfigInput,
) {
  const { error } = await supabaseAdmin.from(table).upsert({
    id: 1,
    ...data,
    updated_at: new Date().toISOString(),
  });
  if (error) throw error;
}
export async function updateLuckyGiftConfig(data: GiftBonusConfigInput) {
  try {
    await upsertGiftBonusConfig("lucky_gift_config", data);
    revalidatePath("/settings/lucky-gifts");
    return { success: true };
  } catch (error: any) {
    console.error("Error updating lucky gift config:", error);
    return { success: false, error: error.message };
  }
}
export async function updateLuckyProGiftConfig(data: GiftBonusConfigInput) {
  try {
    await upsertGiftBonusConfig("lucky_pro_gift_config", data);
    revalidatePath("/settings/lucky-gifts");
    return { success: true };
  } catch (error: any) {
    console.error("Error updating lucky pro gift config:", error);
    return { success: false, error: error.message };
  }
}
export async function setLuckyRoomFanbiSvgaEnabled(enabled: boolean) {
  try {
    const { error } = await supabaseAdmin.from("system_settings").upsert(
      {
        key: "lucky_room_fanbi_svga_enabled",
        value: enabled ? "true" : "false",
        description:
          "Room fanbi SVGA (beaver) after Lucky/Lucky Pro bonus. Independent of multiplier SVGA.",
        updated_at: new Date().toISOString(),
      },
      { onConflict: "key" },
    );
    if (error) throw error;
    revalidatePath("/settings/lucky-gifts");
    revalidatePath("/settings/general");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function setLuckyRoomMultiplierSvgaEnabled(enabled: boolean) {
  try {
    const { error } = await supabaseAdmin.from("system_settings").upsert(
      {
        key: "lucky_room_multiplier_svga_enabled",
        value: enabled ? "true" : "false",
        description:
          "Master switch for all room multiplier (xN) SVGAs after Lucky/Lucky Pro bonus. Individual rows still need is_enabled=true.",
        updated_at: new Date().toISOString(),
      },
      { onConflict: "key" },
    );
    if (error) throw error;
    revalidatePath("/settings/lucky-gifts");
    revalidatePath("/settings/general");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function setLuckyRoomWinSvgaEnabled(enabled: boolean) {
  const a = await setLuckyRoomFanbiSvgaEnabled(enabled);
  if (!a.success) return a;
  return setLuckyRoomMultiplierSvgaEnabled(enabled);
}
export async function setLuckyBonusMultiplierSvgaEnabled(id: string, isEnabled: boolean) {
  try {
    const { error } = await supabaseAdmin
      .from("lucky_bonus_multiplier_svgas")
      .update({ is_enabled: isEnabled, updated_at: new Date().toISOString() })
      .eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/lucky-gifts");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function updateLuckyBonusMultiplierSvga(data: {
  id: string;
  multiplier: number;
  label: string;
  applies_to: "lucky" | "lucky_pro" | "both";
  svga_url: string;
}) {
  try {
    const { error } = await supabaseAdmin
      .from("lucky_bonus_multiplier_svgas")
      .update({
        multiplier: data.multiplier,
        label: data.label,
        applies_to: data.applies_to,
        svga_url: data.svga_url,
        updated_at: new Date().toISOString(),
      })
      .eq("id", data.id);
    if (error) throw error;
    revalidatePath("/settings/lucky-gifts");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function deleteLuckyBonusMultiplierSvga(id: string) {
  try {
    const { error } = await supabaseAdmin
      .from("lucky_bonus_multiplier_svgas")
      .delete()
      .eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/lucky-gifts");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function resetLuckyDailyCaps(scope: "lucky" | "lucky_pro" | "both" = "both") {
  try {
    const now = new Date().toISOString();
    const doLucky = scope === "lucky" || scope === "both";
    const doPro = scope === "lucky_pro" || scope === "both";
    if (doLucky) {
      const { error } = await supabaseAdmin
        .from("lucky_gift_config")
        .update({ daily_cap_window_start: now, updated_at: now })
        .eq("id", 1);
      if (error) throw error;
      const { error: c1 } = await supabaseAdmin
        .from("lucky_gift_counters")
        .delete()
        .gte("gift_count", 0);
      if (c1) throw c1;
      const { error: c2 } = await supabaseAdmin
        .from("lucky_gift_sender_counters")
        .delete()
        .gte("gift_count", 0);
      if (c2) throw c2;
    }
    if (doPro) {
      const { error } = await supabaseAdmin
        .from("lucky_pro_gift_config")
        .update({ daily_cap_window_start: now, updated_at: now })
        .eq("id", 1);
      if (error) throw error;
      const { error: c1 } = await supabaseAdmin
        .from("lucky_pro_gift_counters")
        .delete()
        .gte("gift_count", 0);
      if (c1) throw c1;
      const { error: c2 } = await supabaseAdmin
        .from("lucky_pro_gift_sender_counters")
        .delete()
        .gte("gift_count", 0);
      if (c2) throw c2;
    }
    revalidatePath("/settings/lucky-gifts");
    return { success: true as const };
  } catch (error: any) {
    console.error("resetLuckyDailyCaps:", error);
    return { success: false as const, error: error.message };
  }
}
