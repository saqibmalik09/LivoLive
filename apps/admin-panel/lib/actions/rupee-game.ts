"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
export type RupeeGameCampaignInput = {
  id?: string;
  title: string;
  subtitle: string;
  hero_image_url?: string | null;
  entry_price_coins: number;
  starts_at: string;
  ends_at: string;
  status: "draft" | "active" | "ended" | "drawn";
  max_entries_per_user: number;
  draw_mode: "manual" | "auto_random";
  refund_non_winners: boolean;
  announcement_hours: number;
  sort_order: number;
  is_active: boolean;
};
export type RupeeGamePrizeInput = {
  id?: string;
  campaign_id: string;
  name: string;
  image_url?: string | null;
  original_value_label: string;
  sort_order: number;
  coming_soon?: boolean;
};
export type RupeeGameHelpInput = {
  id: string;
  title: string;
  content: {
    items: string[];
  };
  sort_order: number;
  is_expanded_default: boolean;
};
const REVALIDATE = "/settings/rupee-game";
export async function listRupeeGameCampaigns() {
  const { data, error } = await supabaseAdmin
    .from("rupee_game_campaigns")
    .select("*")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}
export async function upsertRupeeGameCampaign(campaign: RupeeGameCampaignInput) {
  const payload = {
    title: campaign.title,
    subtitle: campaign.subtitle,
    hero_image_url: campaign.hero_image_url ?? null,
    entry_price_coins: campaign.entry_price_coins,
    starts_at: campaign.starts_at,
    ends_at: campaign.ends_at,
    status: campaign.status,
    max_entries_per_user: campaign.max_entries_per_user,
    draw_mode: campaign.draw_mode,
    refund_non_winners: campaign.refund_non_winners,
    announcement_hours: campaign.announcement_hours,
    sort_order: campaign.sort_order,
    is_active: campaign.is_active,
    updated_at: new Date().toISOString(),
  };
  if (campaign.id) {
    const { error } = await supabaseAdmin
      .from("rupee_game_campaigns")
      .update(payload)
      .eq("id", campaign.id);
    if (error) throw error;
  } else {
    const { error } = await supabaseAdmin.from("rupee_game_campaigns").insert(payload);
    if (error) throw error;
  }
  revalidatePath(REVALIDATE);
  return { success: true };
}
export async function deleteRupeeGameCampaign(id: string) {
  const { error } = await supabaseAdmin.from("rupee_game_campaigns").delete().eq("id", id);
  if (error) throw error;
  revalidatePath(REVALIDATE);
  return { success: true };
}
export async function listRupeeGamePrizes(campaignId: string) {
  const { data, error } = await supabaseAdmin
    .from("rupee_game_prizes")
    .select("*, users:winner_user_id(id, username)")
    .eq("campaign_id", campaignId)
    .order("sort_order", { ascending: true });
  if (error) throw error;
  return data ?? [];
}
export async function upsertRupeeGamePrize(prize: RupeeGamePrizeInput) {
  const payload = {
    campaign_id: prize.campaign_id,
    name: prize.name,
    image_url: prize.image_url ?? null,
    original_value_label: prize.original_value_label,
    sort_order: prize.sort_order,
    coming_soon: prize.coming_soon ?? false,
    updated_at: new Date().toISOString(),
  };
  if (prize.id) {
    const { error } = await supabaseAdmin
      .from("rupee_game_prizes")
      .update(payload)
      .eq("id", prize.id);
    if (error) throw error;
  } else {
    const { error } = await supabaseAdmin.from("rupee_game_prizes").insert(payload);
    if (error) throw error;
  }
  revalidatePath(REVALIDATE);
  return { success: true };
}
export async function deleteRupeeGamePrize(id: string) {
  const { error } = await supabaseAdmin.from("rupee_game_prizes").delete().eq("id", id);
  if (error) throw error;
  revalidatePath(REVALIDATE);
  return { success: true };
}
export async function listRupeeGameEntries(prizeId?: string) {
  let query = supabaseAdmin
    .from("rupee_game_entries")
    .select(
      "*, users:user_id(id, username), rupee_game_prizes:prize_id(name), rupee_game_campaigns:campaign_id(title)",
    )
    .order("created_at", { ascending: false })
    .limit(200);
  if (prizeId) {
    query = query.eq("prize_id", prizeId);
  }
  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
}
export async function listRupeeGameHelpSections() {
  const { data, error } = await supabaseAdmin
    .from("rupee_game_help_sections")
    .select("*")
    .order("sort_order", { ascending: true });
  if (error) throw error;
  return data ?? [];
}
export async function updateRupeeGameHelpSection(section: RupeeGameHelpInput) {
  const { error } = await supabaseAdmin
    .from("rupee_game_help_sections")
    .update({
      title: section.title,
      content: section.content,
      sort_order: section.sort_order,
      is_expanded_default: section.is_expanded_default,
      updated_at: new Date().toISOString(),
    })
    .eq("id", section.id);
  if (error) throw error;
  revalidatePath(REVALIDATE);
  return { success: true };
}
export async function drawRupeeGameWinner(prizeId: string, userId?: string | null) {
  const { data, error } = await supabaseAdmin.rpc("draw_rupee_game_winner", {
    p_prize_id: prizeId,
    p_user_id: userId ?? null,
  });
  if (error) throw error;
  revalidatePath(REVALIDATE);
  return data;
}
export async function refundRupeeGameLosers(prizeId: string) {
  const { data, error } = await supabaseAdmin.rpc("refund_rupee_game_losers", {
    p_prize_id: prizeId,
  });
  if (error) throw error;
  revalidatePath(REVALIDATE);
  return data;
}
export async function runAutoDrawEndedCampaigns() {
  const { data, error } = await supabaseAdmin.rpc("auto_draw_ended_campaigns");
  if (error) throw error;
  revalidatePath(REVALIDATE);
  return data;
}
export async function uploadRupeeGameImage(formData: FormData) {
  try {
    const file = formData.get("file") as File;
    if (!file) throw new Error("No file provided");
    const fileName = `rupee-game/${Date.now()}-${file.name.replace(/\s+/g, "_")}`;
    const buffer = Buffer.from(await file.arrayBuffer());
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType: file.type || "image/png",
    });
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
