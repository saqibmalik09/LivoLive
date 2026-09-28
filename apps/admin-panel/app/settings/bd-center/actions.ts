"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function listAgencySalaryLevels() {
  const { data, error } = await supabaseAdmin
    .from("agency_salary_level_configs")
    .select("*")
    .order("level", { ascending: true });
  if (error) throw new Error(error.message);
  return data ?? [];
}
export async function updateAgencySalaryLevel(formData: FormData) {
  const level = Number(formData.get("level"));
  const charm_target = Number(formData.get("charm_target"));
  const charm_salary_usd = Number(formData.get("charm_salary_usd"));
  const agent_salary_usd = Number(formData.get("agent_salary_usd"));
  const { error } = await supabaseAdmin
    .from("agency_salary_level_configs")
    .update({ charm_target, charm_salary_usd, agent_salary_usd })
    .eq("level", level);
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
}
export async function listBdLevels() {
  const { data, error } = await supabaseAdmin
    .from("bd_level_configs")
    .select("*")
    .order("level", { ascending: true });
  if (error) throw new Error(error.message);
  return data ?? [];
}
export async function updateBdLevel(formData: FormData) {
  const level = Number(formData.get("level"));
  const agency_target_usd = Number(formData.get("agency_target_usd"));
  const basic_salary_usd = Number(formData.get("basic_salary_usd"));
  const commission_usd = Number(formData.get("commission_usd"));
  const new_bd_commission_usd = Number(formData.get("new_bd_commission_usd"));
  const { error } = await supabaseAdmin
    .from("bd_level_configs")
    .update({
      agency_target_usd,
      basic_salary_usd,
      commission_usd,
      new_bd_commission_usd,
    })
    .eq("level", level);
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
}
export async function getBdCenterSettings() {
  const { data, error } = await supabaseAdmin
    .from("bd_center_settings")
    .select("*")
    .eq("id", 1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}
export async function getGiftPolicySettings() {
  const { data, error } = await supabaseAdmin
    .from("policy_gift_settings")
    .select("*")
    .eq("id", 1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}
export async function updateGiftHostPercent(formData: FormData) {
  const host_gift_percent = Number(formData.get("host_gift_percent"));
  const { error } = await supabaseAdmin
    .from("policy_gift_settings")
    .upsert({ id: 1, host_gift_percent, updated_at: new Date().toISOString() });
  if (error) throw new Error(error.message);
  const official = 100 - host_gift_percent;
  await supabaseAdmin
    .from("commission_configs")
    .update({
      host_pc: host_gift_percent,
      agency_pc: 0,
      bd_pc: 0,
      bd_admin_pc: 0,
      super_bd_pc: 0,
      official_pc: official,
      admin_pc: official,
    })
    .eq("id", 1);
  revalidatePath("/settings/bd-center");
}
export async function executeAgencyPeriodPayout(formData: FormData) {
  const period_id = String(formData.get("period_id") || "").trim();
  if (!period_id) throw new Error("period_id required");
  const { data, error } = await supabaseAdmin.rpc("execute_agency_period_payout", {
    p_period_id: period_id,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
  return data;
}
export async function executeBdMonthlyPayout(formData: FormData) {
  const period = String(formData.get("period_yyyy_mm") || "").trim();
  if (!period) throw new Error("period required");
  const { data, error } = await supabaseAdmin.rpc("execute_bd_monthly_payout", {
    p_period_yyyy_mm: period,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
  return data;
}
export async function listStaffRoleCosmetics() {
  const { data, error } = await supabaseAdmin
    .from("staff_role_cosmetics")
    .select(
      "role, frame_shop_item_id, tag_shop_item_id, duration_days, frame:frame_shop_item_id(id, name, image_url), tag:tag_shop_item_id(id, name, image_url)",
    )
    .order("role");
  if (error) throw new Error(error.message);
  return data ?? [];
}
export async function updateStaffRoleCosmetics(formData: FormData) {
  const role = String(formData.get("role") || "").trim();
  if (role !== "assistant" && role !== "customer_service") {
    throw new Error("Invalid role");
  }
  const frameRaw = String(formData.get("frame_shop_item_id") || "").trim();
  const tagRaw = String(formData.get("tag_shop_item_id") || "").trim();
  const durationRaw = String(formData.get("duration_days") || "").trim();
  const { error } = await supabaseAdmin.from("staff_role_cosmetics").upsert({
    role,
    frame_shop_item_id: frameRaw || null,
    tag_shop_item_id: tagRaw || null,
    duration_days: durationRaw ? Number(durationRaw) : null,
    updated_at: new Date().toISOString(),
  });
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
}
export async function backfillStaffRoleCosmetics(formData: FormData) {
  const role = String(formData.get("role") || "").trim() || null;
  const { data, error } = await supabaseAdmin.rpc("backfill_staff_role_cosmetics", {
    p_role: role === "assistant" || role === "customer_service" ? role : null,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
  return data;
}
export async function listBdGiftPackSlots() {
  const { data, error } = await supabaseAdmin
    .from("bd_gift_pack_assets")
    .select(
      "level, feature_key, label, duration_days, shop_item_id, image_url, sort_order, shop_item:shop_item_id(id, name, image_url)",
    )
    .order("level", { ascending: true })
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []).map((row: any) => {
    const shop = Array.isArray(row.shop_item) ? row.shop_item[0] : row.shop_item;
    return {
      level: row.level as number,
      feature_key: row.feature_key as string,
      label: (row.label as string | null) ?? null,
      duration_days: (row.duration_days as number) ?? 30,
      shop_item_id: (row.shop_item_id as string | null) ?? null,
      image_url: (row.image_url as string | null) ?? null,
      shop_item_name: (shop?.name as string | null) ?? null,
      shop_item_image: (shop?.image_url as string | null) ?? null,
    };
  });
}
export async function saveBdGiftPackSlot(input: {
  level: number;
  feature_key: string;
  shop_item_id?: string | null;
  image_url?: string | null;
  label?: string | null;
  duration_days?: number;
}) {
  const level = Number(input.level);
  const feature_key = String(input.feature_key || "").trim();
  if (!level || !feature_key) throw new Error("level and feature_key required");
  const { error } = await supabaseAdmin.from("bd_gift_pack_assets").upsert(
    {
      level,
      feature_key,
      shop_item_id: input.shop_item_id || null,
      image_url: input.image_url || null,
      label: input.label || null,
      duration_days: input.duration_days ?? 30,
      sort_order: feature_key === "bd_frame" ? 0 : feature_key === "svip" ? 1 : 2,
    },
    { onConflict: "level,feature_key" },
  );
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
}
export async function saveBdLevelBadgeUrl(level: number, badge_url: string) {
  const lv = Number(level);
  if (!lv) throw new Error("level required");
  const { error } = await supabaseAdmin
    .from("bd_level_configs")
    .update({ badge_url: badge_url || null })
    .eq("level", lv);
  if (error) throw new Error(error.message);
  revalidatePath("/settings/bd-center");
}
