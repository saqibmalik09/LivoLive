"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export type LevelRewardSelection = {
  id?: string;
  name?: string;
  image_url?: string | null;
};
export type LevelRewardsMap = Partial<
  Record<"frame" | "bubble" | "card_background" | "entrance", LevelRewardSelection | null>
>;
export type AgencyProfileFrames = Partial<
  Record<"hero_frame" | "honor_frame" | "charm_frame", string | null>
>;
const REWARD_KEYS = ["frame", "bubble", "card_background", "entrance"] as const;
const PROFILE_FRAME_KEYS = ["hero_frame", "honor_frame", "charm_frame"] as const;
async function upsertAgencyProfileFrames(level: number, frames?: AgencyProfileFrames) {
  if (!frames) return;
  for (const key of PROFILE_FRAME_KEYS) {
    const url = frames[key];
    const { data: existing } = await supabaseAdmin
      .from("agency_level_assets")
      .select("id")
      .eq("level", level)
      .eq("feature_key", key)
      .maybeSingle();
    if (url) {
      if (existing) {
        await supabaseAdmin
          .from("agency_level_assets")
          .update({ image_url: url, shop_item_id: null })
          .eq("id", existing.id);
      } else {
        await supabaseAdmin.from("agency_level_assets").insert({
          level,
          feature_key: key,
          image_url: url,
        });
      }
    } else if (existing) {
      await supabaseAdmin.from("agency_level_assets").delete().eq("id", existing.id);
    }
  }
}
async function upsertAgencyRewards(level: number, rewards?: LevelRewardsMap) {
  if (!rewards) return;
  for (const key of REWARD_KEYS) {
    const reward = rewards[key];
    const { data: existing } = await supabaseAdmin
      .from("agency_level_assets")
      .select("id")
      .eq("level", level)
      .eq("feature_key", key)
      .maybeSingle();
    if (reward?.id) {
      if (existing) {
        await supabaseAdmin
          .from("agency_level_assets")
          .update({ shop_item_id: reward.id, image_url: null })
          .eq("id", existing.id);
      } else {
        await supabaseAdmin.from("agency_level_assets").insert({
          level,
          feature_key: key,
          shop_item_id: reward.id,
        });
      }
    } else if (existing) {
      await supabaseAdmin.from("agency_level_assets").delete().eq("id", existing.id);
    }
  }
}
async function deleteAgencyLevelAssets(level: number) {
  await supabaseAdmin.from("agency_level_assets").delete().eq("level", level);
}
async function upsertWealthRewards(level: number, rewards?: LevelRewardsMap) {
  if (!rewards) return;
  for (const key of REWARD_KEYS) {
    const reward = rewards[key];
    const { data: existing } = await supabaseAdmin
      .from("wealth_level_assets")
      .select("id")
      .eq("level", level)
      .eq("feature_key", key)
      .maybeSingle();
    if (reward?.id) {
      if (existing) {
        await supabaseAdmin
          .from("wealth_level_assets")
          .update({ shop_item_id: reward.id })
          .eq("id", existing.id);
      } else {
        await supabaseAdmin.from("wealth_level_assets").insert({
          level,
          feature_key: key,
          shop_item_id: reward.id,
        });
      }
    } else if (existing) {
      await supabaseAdmin.from("wealth_level_assets").delete().eq("id", existing.id);
    }
  }
}
async function upsertCharmRewards(level: number, rewards?: LevelRewardsMap) {
  if (!rewards) return;
  for (const key of REWARD_KEYS) {
    const reward = rewards[key];
    const { data: existing } = await supabaseAdmin
      .from("charm_level_assets")
      .select("id")
      .eq("level", level)
      .eq("feature_key", key)
      .maybeSingle();
    if (reward?.id) {
      if (existing) {
        await supabaseAdmin
          .from("charm_level_assets")
          .update({ shop_item_id: reward.id })
          .eq("id", existing.id);
      } else {
        await supabaseAdmin.from("charm_level_assets").insert({
          level,
          feature_key: key,
          shop_item_id: reward.id,
          image_url: null,
        });
      }
    } else if (existing) {
      await supabaseAdmin.from("charm_level_assets").delete().eq("id", existing.id);
    }
  }
}
async function deleteWealthRewards(level: number) {
  await supabaseAdmin.from("wealth_level_assets").delete().eq("level", level);
}
export async function updateLevelConfig(category: string, level: number, data: any) {
  let table = "";
  switch (category) {
    case "user":
      table = "level_configs";
      data.category = "user_level";
      break;
    case "wealth":
      table = "level_configs";
      data.category = "user_wealth";
      break;
    case "charm":
      table = "charm_level_configs";
      break;
    case "room":
      table = "room_level_configs";
      break;
    case "family":
      table = "family_level_configs";
      break;
    case "cp":
      table = "cp_level_configs";
      break;
    case "agency":
      table = "agency_level_configs";
      break;
    default:
      throw new Error("Invalid level category");
  }
  const { badge_url, rewards, profile_frames, ...configData } = data;
  if (category === "agency") {
    const { error: configError } = await supabaseAdmin
      .from("agency_level_configs")
      .update({
        ...configData,
        ...(badge_url !== undefined ? { badge_url } : {}),
      })
      .eq("level", level);
    if (configError) throw configError;
    await upsertAgencyProfileFrames(level, profile_frames);
    await upsertAgencyRewards(level, rewards);
  } else if (category === "charm") {
    const { error: configError } = await supabaseAdmin
      .from("charm_level_configs")
      .update(configData)
      .eq("level", level);
    if (configError) throw configError;
    if (badge_url !== undefined) {
      const { data: existingAsset } = await supabaseAdmin
        .from("charm_level_assets")
        .select("id")
        .eq("level", level)
        .eq("feature_key", "badge")
        .maybeSingle();
      if (existingAsset) {
        await supabaseAdmin
          .from("charm_level_assets")
          .update({ image_url: badge_url })
          .eq("id", existingAsset.id);
      } else if (badge_url) {
        await supabaseAdmin.from("charm_level_assets").insert({
          level,
          feature_key: "badge",
          image_url: badge_url,
        });
      }
    }
    await upsertCharmRewards(level, rewards);
  } else if (table === "level_configs") {
    const payload = { ...configData };
    if (badge_url !== undefined) {
      payload.badge_url = badge_url;
    }
    if (data.category != null) {
      payload.category = data.category;
    }
    const { error } = await supabaseAdmin
      .from(table)
      .update(payload)
      .eq("category", payload.category)
      .eq("level", level);
    if (error) throw error;
    if (category === "wealth") {
      await upsertWealthRewards(level, rewards);
    }
  } else {
    const { error } = await supabaseAdmin.from(table).update(configData).eq("level", level);
    if (error) throw error;
  }
  revalidatePath(`/settings/levels/${category}`);
  return { success: true };
}
export async function deleteLevelConfig(category: string, level: number) {
  if (category === "agency") {
    await deleteAgencyLevelAssets(level);
    const { error } = await supabaseAdmin.from("agency_level_configs").delete().eq("level", level);
    if (error) throw error;
  } else if (category === "charm") {
    await supabaseAdmin.from("charm_level_assets").delete().eq("level", level);
    const { error } = await supabaseAdmin.from("charm_level_configs").delete().eq("level", level);
    if (error) throw error;
  } else if (category === "wealth") {
    await deleteWealthRewards(level);
    const { error } = await supabaseAdmin
      .from("level_configs")
      .delete()
      .eq("category", "user_wealth")
      .eq("level", level);
    if (error) throw error;
  } else {
    let table = "";
    let dbCategory = "";
    switch (category) {
      case "user":
        table = "level_configs";
        dbCategory = "user_level";
        break;
      case "room":
        table = "room_level_configs";
        break;
      case "family":
        table = "family_level_configs";
        break;
      case "cp":
        table = "cp_level_configs";
        break;
      default:
        throw new Error("Invalid level category");
    }
    const query = supabaseAdmin.from(table).delete().eq("level", level);
    if (dbCategory) {
      query.eq("category", dbCategory);
    }
    const { error } = await query;
    if (error) throw error;
  }
  revalidatePath(`/settings/levels/${category}`);
  return { success: true };
}
export async function addLevelConfig(category: string, data: any) {
  let table = "";
  let dbCategory = "";
  switch (category) {
    case "user":
      table = "level_configs";
      dbCategory = "user_level";
      break;
    case "wealth":
      table = "level_configs";
      dbCategory = "user_wealth";
      break;
    case "charm":
      table = "charm_level_configs";
      break;
    case "room":
      table = "room_level_configs";
      break;
    case "family":
      table = "family_level_configs";
      break;
    case "cp":
      table = "cp_level_configs";
      break;
    case "agency":
      table = "agency_level_configs";
      break;
    default:
      throw new Error("Invalid level category");
  }
  const { badge_url, rewards, profile_frames, ...configData } = data;
  if (dbCategory) {
    configData.category = dbCategory;
  }
  if (category === "agency") {
    const { error: configError } = await supabaseAdmin.from("agency_level_configs").insert({
      ...configData,
      ...(badge_url != null ? { badge_url } : {}),
    });
    if (configError) throw configError;
    await upsertAgencyProfileFrames(data.level, profile_frames);
    await upsertAgencyRewards(data.level, rewards);
  } else if (category === "charm") {
    const { error: configError } = await supabaseAdmin
      .from("charm_level_configs")
      .insert(configData);
    if (configError) throw configError;
    if (badge_url) {
      await supabaseAdmin.from("charm_level_assets").insert({
        level: data.level,
        feature_key: "badge",
        image_url: badge_url,
      });
    }
    await upsertCharmRewards(data.level, rewards);
  } else {
    const insertPayload =
      category === "wealth"
        ? {
            ...configData,
            ...(badge_url != null ? { badge_url } : {}),
            category: dbCategory,
          }
        : configData;
    const { error } = await supabaseAdmin.from(table).insert(insertPayload);
    if (error) throw error;
    if (category === "wealth") {
      await upsertWealthRewards(data.level, rewards);
    }
  }
  revalidatePath(`/settings/levels/${category}`);
  return { success: true };
}
