"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
export type PartyEventKind =
  "cp_native" | "webview" | "weekly_star_native" | "game_star_native" | "sk_host_native";
export type PartyEventRow = {
  id: string;
  title: string;
  subtitle: string;
  banner_url: string;
  event_kind: PartyEventKind;
  action_type: string;
  action_config: Record<string, unknown>;
  start_at: string | null;
  end_at: string | null;
  is_active: boolean;
  priority: number;
  created_at?: string;
  updated_at?: string;
};
export async function createCpPartyEvent(data: {
  title: string;
  subtitle?: string;
  rules?: string;
  rewards?: string;
  cta_label?: string;
  start_at?: string | null;
  end_at?: string | null;
  is_active?: boolean;
  priority?: number;
}) {
  try {
    const { error } = await supabaseAdmin.from("party_events").insert({
      title: data.title.trim(),
      subtitle: (data.subtitle ?? "").trim(),
      banner_url: "",
      event_kind: "cp_native",
      screen_template: "cp_romance",
      action_type: "none",
      action_config: {
        rules: (data.rules ?? "").trim(),
        rewards: (data.rewards ?? "").trim(),
        cta_label: (data.cta_label ?? "").trim() || "Open CP Nest",
      },
      start_at: data.start_at || null,
      end_at: data.end_at || null,
      is_active: data.is_active ?? true,
      priority: data.priority ?? 0,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function createWeeklyStarPartyEvent(data: {
  title: string;
  subtitle?: string;
  rules?: string;
  start_at?: string | null;
  end_at?: string | null;
  is_active?: boolean;
  priority?: number;
}) {
  try {
    const defaultRules = [
      "1. Only the specified gifts received will be counted for points. All other gifts are invalid.",
      "2. For each specified gift of 1 gold coin received, the recipient can accumulate 1 point of event points.",
      "3. The points are updated in real time. The final ranking is based on the list at the end of the event.",
      "4. After the event ends, the system will automatically send the rewards.",
    ].join("\n");
    const { error } = await supabaseAdmin.from("party_events").insert({
      title: data.title.trim(),
      subtitle: (data.subtitle ?? "").trim(),
      banner_url: "",
      event_kind: "weekly_star_native",
      screen_template: "weekly_star",
      action_type: "none",
      action_config: {
        rules: (data.rules ?? "").trim() || defaultRules,
        weekly_star_gifts: [],
        weekly_star_gift_ids: [],
        reward_slots: {},
      },
      start_at: data.start_at || null,
      end_at: data.end_at || null,
      is_active: data.is_active ?? true,
      priority: data.priority ?? 0,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function createGameStarPartyEvent(data: {
  title: string;
  subtitle?: string;
  rules?: string;
  start_at?: string | null;
  end_at?: string | null;
  is_active?: boolean;
  priority?: number;
}) {
  try {
    const defaultRules = [
      "Core Gameplay & Points",
      "• How to Participate: Simply play the designated games (shown on this event screen) during the event period to automatically enter the competition.",
      "• Points Conversion: Every 1 Gold Coin won in a designated game = 1 Point.",
      "• Calculation Rules: Points are based only on Gold Coins won in the admin-selected games. Wins from other games, and coins consumed or lost, will not be counted or deducted.",
      "",
      "Leaderboard Ranking Rules",
      "• The Ranking tab shows the overall Game Star leaderboard from designated-game wins only.",
      "• Higher points rank higher. If points are the same, the player who reached the score first will take the higher rank.",
      "• Rankings update in real time. The final ranking is based on the list at the end of the event.",
      "",
      "Rewards",
      "• Leaderboard Rewards: Players ranked on the Game Star leaderboard will receive exclusive rewards.",
      "• After the overall event concludes, the system will automatically send rewards based on final ranking.",
    ].join("\n");
    const { error } = await supabaseAdmin.from("party_events").insert({
      title: data.title.trim(),
      subtitle: (data.subtitle ?? "").trim(),
      banner_url: "",
      event_kind: "game_star_native",
      screen_template: "game_star",
      action_type: "none",
      action_config: {
        rules: (data.rules ?? "").trim() || defaultRules,
        game_star_game_ids: [],
        reward_slots: {},
      },
      start_at: data.start_at || null,
      end_at: data.end_at || null,
      is_active: data.is_active ?? true,
      priority: data.priority ?? 0,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function createSkHostPartyEvent(data: {
  title: string;
  subtitle?: string;
  rules?: string;
  start_at?: string | null;
  end_at?: string | null;
  is_active?: boolean;
  priority?: number;
}) {
  try {
    const defaultRules = [
      "1. Hosts must meet both broadcast time and charm targets to receive rewards.",
      "2. Hosts must manually claim prizes after each activity period.",
      "3. Cycles run from the 1st–15th and 16th–end of each month. Data resets after each cycle.",
      "4. Event dates follow the active party event window in SK Live.",
      "5. Final interpretation belongs to SK Live.",
    ].join("\n");
    const { error } = await supabaseAdmin.from("party_events").insert({
      title: data.title.trim(),
      subtitle: (data.subtitle ?? "").trim(),
      banner_url: "",
      event_kind: "sk_host_native",
      screen_template: "sk_host_party",
      action_type: "none",
      action_config: {
        rules: (data.rules ?? "").trim() || defaultRules,
        reward_tiers: [],
      },
      start_at: data.start_at || null,
      end_at: data.end_at || null,
      is_active: data.is_active ?? true,
      priority: data.priority ?? 0,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function createWebPartyEvent(data: {
  title: string;
  subtitle?: string;
  web_url: string;
  page_title?: string;
  start_at?: string | null;
  end_at?: string | null;
  is_active?: boolean;
  priority?: number;
}) {
  try {
    const webUrl = data.web_url.trim();
    if (!webUrl) throw new Error("Web URL is required");
    const { error } = await supabaseAdmin.from("party_events").insert({
      title: data.title.trim(),
      subtitle: (data.subtitle ?? "").trim(),
      banner_url: "",
      event_kind: "webview",
      screen_template: "recharge",
      action_type: "none",
      action_config: {
        web_url: webUrl,
        page_title: (data.page_title ?? "").trim() || data.title.trim(),
      },
      start_at: data.start_at || null,
      end_at: data.end_at || null,
      is_active: data.is_active ?? true,
      priority: data.priority ?? 0,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function updatePartyEvent(id: string, data: Record<string, unknown>) {
  try {
    const row = {
      ...data,
      updated_at: new Date().toISOString(),
    };
    const { error } = await supabaseAdmin.from("party_events").update(row).eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function deletePartyEvent(id: string) {
  try {
    const { error } = await supabaseAdmin.from("party_events").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function uploadPartyEventBanner(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const eventId = (formData.get("eventId") as string) || "";
    if (!eventId) throw new Error("Missing event id");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : "banner.png";
    const ext = originalName.split(".").pop()?.toLowerCase() || "png";
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const fileName = `party-events/${eventId}-${Date.now()}.${ext}`;
    const contentType =
      ext === "jpg" || ext === "jpeg"
        ? "image/jpeg"
        : ext === "webp"
          ? "image/webp"
          : "image/png";
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    const { error: dbError } = await supabaseAdmin
      .from("party_events")
      .update({
        banner_url: publicUrl,
        updated_at: new Date().toISOString(),
      })
      .eq("id", eventId);
    if (dbError) throw dbError;
    revalidatePath("/settings/party-events");
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export type GiftPickerItem = {
  id: string;
  name: string;
  image_url: string;
  price_coins: number;
};
export type PartyRewardShopItem = {
  id: string;
  name: string;
  image_url: string;
  price_coins: number;
};
export async function listShopItemsForPartyEventRewards(): Promise<PartyRewardShopItem[]> {
  const { data, error } = await supabaseAdmin
    .from("shop_items")
    .select("id, name, image_url, price_coins")
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(500);
  if (error) {
    console.error("[listShopItemsForPartyEventRewards]", error.message);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: String(row.id),
    name: String(row.name ?? "Item"),
    image_url: String(row.image_url ?? ""),
    price_coins: Number(row.price_coins ?? 0),
  }));
}
export async function settlePartyEventRewards(eventId: string, force = false) {
  try {
    if (!eventId) throw new Error("Missing event id");
    const { data, error } = await supabaseAdmin.rpc("settle_party_event_rewards", {
      p_event_id: eventId,
      p_force: force,
    });
    if (error) throw error;
    revalidatePath("/settings/party-events");
    return { success: true as const, result: data };
  } catch (error: unknown) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function listGiftItemsForCpEvent(): Promise<GiftPickerItem[]> {
  const { data, error } = await supabaseAdmin
    .from("shop_items")
    .select("id, name, image_url, price_coins")
    .eq("is_gift", true)
    .eq("is_active", true)
    .order("price_coins", { ascending: true });
  if (error) {
    console.error("[listGiftItemsForCpEvent]", error.message);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: String(row.id),
    name: String(row.name ?? "Gift"),
    image_url: String(row.image_url ?? ""),
    price_coins: Number(row.price_coins ?? 0),
  }));
}
export type GameConfigPickerItem = {
  id: string;
  name: string;
  icon_url: string;
  slug: string;
};
export async function listGameConfigsForGameStar(): Promise<GameConfigPickerItem[]> {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("id, name, icon_url, slug")
    .eq("is_active", true)
    .order("sort_order", { ascending: true });
  if (error) {
    console.error("[listGameConfigsForGameStar]", error.message);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: String(row.id),
    name: String(row.name ?? "Game"),
    icon_url: String(row.icon_url ?? ""),
    slug: String(row.slug ?? ""),
  }));
}
export async function uploadCpEventRewardImage(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const eventId = (formData.get("eventId") as string) || "";
    const slotKey = (formData.get("slotKey") as string) || "reward";
    if (!eventId) throw new Error("Missing event id");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : "reward.png";
    const ext = originalName.split(".").pop()?.toLowerCase() || "png";
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const safeSlot = slotKey.replace(/[^a-zA-Z0-9_-]/g, "_");
    const fileName = `party-events/rewards/${eventId}-${safeSlot}-${Date.now()}.${ext}`;
    const contentType =
      ext === "jpg" || ext === "jpeg"
        ? "image/jpeg"
        : ext === "webp"
          ? "image/webp"
          : "image/png";
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    revalidatePath("/settings/party-events");
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
      url: undefined as string | undefined,
    };
  }
}
