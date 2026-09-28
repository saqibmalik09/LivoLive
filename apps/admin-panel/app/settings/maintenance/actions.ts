"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export type MaintenanceSettings = {
  enabled: boolean;
  message: string;
};
const MODE_KEY = "app_maintenance_mode";
const MESSAGE_KEY = "app_maintenance_message";
const MODE_DESCRIPTION =
  'Global maintenance kill-switch. "true" blocks the mobile app and rejects all realtime gateway connections.';
const MESSAGE_DESCRIPTION =
  'Message shown on the maintenance screen while app_maintenance_mode is "true".';
async function upsertSetting(key: string, value: string, description: string) {
  const { data, error } = await supabaseAdmin
    .from("system_settings")
    .update({ value, updated_at: new Date().toISOString(), description })
    .eq("key", key)
    .select("key");
  if (error) throw error;
  if (!data?.length) {
    const { error: insertError } = await supabaseAdmin.from("system_settings").insert({
      key,
      value,
      description,
      updated_at: new Date().toISOString(),
    });
    if (insertError) throw insertError;
  }
}
export async function loadMaintenanceSettings(): Promise<MaintenanceSettings> {
  const { data, error } = await supabaseAdmin
    .from("system_settings")
    .select("key, value")
    .in("key", [MODE_KEY, MESSAGE_KEY]);
  if (error) throw error;
  const map = Object.fromEntries((data || []).map((r) => [r.key, r.value ?? ""]));
  return {
    enabled: String(map[MODE_KEY] || "false").trim() === "true",
    message: map[MESSAGE_KEY] || "",
  };
}
export async function saveMaintenanceSettings(input: MaintenanceSettings) {
  try {
    await upsertSetting(MESSAGE_KEY, input.message.trim(), MESSAGE_DESCRIPTION);
    await upsertSetting(MODE_KEY, input.enabled ? "true" : "false", MODE_DESCRIPTION);
    revalidatePath("/settings/maintenance");
    revalidatePath("/settings");
    return { success: true as const };
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    return { success: false as const, error: message };
  }
}
