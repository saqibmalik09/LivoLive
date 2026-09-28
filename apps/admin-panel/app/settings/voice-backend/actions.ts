"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";

export type VoiceBackendId = "zego" | "orbit" | "livekit";

export type VoiceBackendSettings = {
  voice_backend: VoiceBackendId;
  orbit_api_url: string;
  orbit_livekit_url: string;
  livekit_url: string;
  livekit_api_key: string;
  /** Never populated on load. Blank on save means "keep the stored secret". */
  livekit_api_secret: string;
  /** Comma-separated user ids forced onto LiveKit regardless of the active backend. */
  livekit_test_user_ids: string;
  /** Read-only indicator for the UI. */
  livekit_secret_set?: boolean;
};

const BACKENDS: VoiceBackendId[] = ["zego", "orbit", "livekit"];

function normalizeBackend(value: unknown): VoiceBackendId {
  return BACKENDS.includes(value as VoiceBackendId) ? (value as VoiceBackendId) : "zego";
}

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
  const keys = [
    "voice_backend",
    "orbit_api_url",
    "orbit_livekit_url",
    "livekit_url",
    "livekit_api_key",
    "livekit_api_secret",
    "livekit_test_user_ids",
  ];
  const { data, error } = await supabaseAdmin
    .from("system_settings")
    .select("key, value")
    .in("key", keys);
  if (error) throw error;
  const map = Object.fromEntries((data || []).map((r) => [r.key, r.value ?? ""]));
  return {
    voice_backend: normalizeBackend(map.voice_backend),
    orbit_api_url: map.orbit_api_url || "",
    orbit_livekit_url: map.orbit_livekit_url || "",
    livekit_url: map.livekit_url || "",
    livekit_api_key: map.livekit_api_key || "",
    // The secret is never sent to the browser.
    livekit_api_secret: "",
    livekit_test_user_ids: map.livekit_test_user_ids || "",
    livekit_secret_set: Boolean(map.livekit_api_secret),
  };
}

export async function saveVoiceBackendSettings(input: VoiceBackendSettings) {
  try {
    const backend = normalizeBackend(input.voice_backend);

    if (backend === "livekit") {
      const url = input.livekit_url.trim();
      if (!/^wss:\/\/.+/.test(url)) {
        return { success: false as const, error: "LiveKit URL must start with wss://" };
      }
      if (!input.livekit_api_key.trim()) {
        return { success: false as const, error: "LiveKit API key is required" };
      }
      const { data: existing } = await supabaseAdmin
        .from("system_settings")
        .select("value")
        .eq("key", "livekit_api_secret")
        .maybeSingle();
      if (!input.livekit_api_secret.trim() && !existing?.value) {
        return { success: false as const, error: "LiveKit API secret is required" };
      }
    }

    await upsertSetting(
      "voice_backend",
      backend,
      "Room voice media backend: zego, orbit (Orbit Voice API), or livekit (direct LiveKit).",
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
    await upsertSetting(
      "livekit_url",
      input.livekit_url.trim().replace(/\/$/, ""),
      "LiveKit WebSocket URL, e.g. wss://voice.skliveparty.online. Used when voice_backend=livekit.",
    );
    await upsertSetting(
      "livekit_api_key",
      input.livekit_api_key.trim(),
      "LiveKit API key. Used when voice_backend=livekit.",
    );
    await upsertSetting(
      "livekit_test_user_ids",
      input.livekit_test_user_ids
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
        .join(","),
      "User ids forced onto the LiveKit backend regardless of voice_backend. For testing a new build against production without moving everyone.",
    );
    // Blank secret means keep whatever is stored — the browser never receives it.
    if (input.livekit_api_secret.trim()) {
      await upsertSetting(
        "livekit_api_secret",
        input.livekit_api_secret.trim(),
        "LiveKit API secret. Server-side only; never returned to the admin UI.",
      );
    }

    revalidatePath("/settings/voice-backend");
    revalidatePath("/settings");
    return { success: true as const };
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    return { success: false as const, error: message };
  }
}
