"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export type VoiceBackendSettings = {
  voice_backend: "zego" | "orbit";
  orbit_api_url: string;
  orbit_livekit_url: string;
};
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
export async function loadVoiceBackendSettings(): Promise<VoiceBackendSettings> {
  const keys = ["voice_backend", "orbit_api_url", "orbit_livekit_url"];
  const { data, error } = await supabaseAdmin
    .from("system_settings")
    .select("key, value")
    .in("key", keys);
  if (error) throw error;
  const map = Object.fromEntries((data || []).map((r) => [r.key, r.value ?? ""]));
  const backend = map.voice_backend === "orbit" ? "orbit" : "zego";
  return {
    voice_backend: backend,
    orbit_api_url: map.orbit_api_url || "",
    orbit_livekit_url: map.orbit_livekit_url || "",
  };
}
export async function saveVoiceBackendSettings(input: VoiceBackendSettings) {
  try {
    const backend = input.voice_backend === "orbit" ? "orbit" : "zego";
    await upsertSetting(
      "voice_backend",
      backend,
      "Room voice media backend: zego (default) or orbit (LiveKit / Orbit Voice VM).",
    );
    await upsertSetting(
      "orbit_api_url",
      input.orbit_api_url.trim().replace(/\/$/, ""),
      "Orbit Voice API base URL. Used when voice_backend=orbit.",
    );
    await upsertSetting(
      "orbit_livekit_url",
      input.orbit_livekit_url.trim().replace(/\/$/, ""),
      "Orbit LiveKit WebSocket URL. Used when voice_backend=orbit.",
    );
    revalidatePath("/settings/voice-backend");
    revalidatePath("/settings");
    return { success: true as const };
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    return { success: false as const, error: message };
  }
}
