"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
import { isSvgaRankingAsset, resolveRankingAssetContentType } from "@/lib/ranking-asset-media";
import { uploadShopAssetToR2 } from "@/lib/r2";
export async function upsertShopItem(data: any) {
  try {
    const { id, ...updateData } = data;
    let res;
    if (id) {
      res = await supabaseAdmin.from("shop_items").update(updateData).eq("id", id);
    } else {
      res = await supabaseAdmin.from("shop_items").insert(updateData);
    }
    if (res.error) throw res.error;
    revalidatePath("/shop");
    if (id) revalidatePath(`/shop/${id}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error upserting shop item:", error);
    return { success: false, error: error.message };
  }
}
/** Shop / gift / level media → Cloudflare R2 only (CDN public URL in DB). */
export async function uploadFile(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file provided");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : "upload.bin";
    const safeName = originalName.replace(/\s+/g, "_");
    const isSvga = isSvgaRankingAsset(originalName, fileEntry.type);
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const fileName = `${Date.now()}-${safeName}`;
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    // Original + R2 WebP thumbs (t/w*_q90/…) for fast app tiles — no Supabase render.
    const { publicUrl } = await uploadShopAssetToR2({
      key: fileName,
      body: buffer,
      contentType,
    });
    return { success: true as const, url: publicUrl, isSvga };
  } catch (error: any) {
    console.error("Error uploading file:", error);
    return { success: false as const, error: error.message };
  }
}
export type BulkShopItemInput = {
  name: string;
  category_id: string;
  price_coins: number;
  duration_days: number;
  image_url?: string;
  svga_url?: string;
  is_active?: boolean;
  is_for_sale?: boolean;
  is_gift?: boolean;
  is_full_screen?: boolean;
  source_type?: string;
};
export async function bulkCreateShopItems(items: BulkShopItemInput[]) {
  try {
    if (!items.length) throw new Error("No items to create");
    const rows = items.map((item) => ({
      name: item.name.trim(),
      category_id: item.category_id,
      price_coins: item.price_coins ?? 0,
      duration_days: item.duration_days ?? 7,
      image_url: item.image_url?.trim() || "",
      svga_url: item.svga_url?.trim() || "",
      description: "",
      sound_url: "",
      is_active: item.is_active ?? true,
      is_for_sale: item.is_for_sale ?? true,
      is_gift: item.is_gift ?? false,
      is_full_screen: item.is_full_screen ?? false,
      required_vip_level: 0,
      required_wealth_value: 0,
      source_type: item.source_type || "shop",
    }));
    const { error } = await supabaseAdmin.from("shop_items").insert(rows);
    if (error) throw error;
    revalidatePath("/shop");
    return { success: true as const, count: rows.length };
  } catch (error: any) {
    console.error("Error bulk creating shop items:", error);
    return { success: false as const, error: error.message };
  }
}
export async function deleteShopItem(id: string) {
  try {
    const { error } = await supabaseAdmin.from("shop_items").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/shop");
    return { success: true };
  } catch (error: any) {
    console.error("Error deleting shop item:", error);
    return { success: false, error: error.message };
  }
}
export type ShopUserSearchResult = {
  id: string;
  username: string;
  short_id: string | null;
  avatar_url: string | null;
};
export async function searchUsersForShopGrant(query: string): Promise<
  | {
      success: true;
      users: ShopUserSearchResult[];
    }
  | {
      success: false;
      error: string;
    }
> {
  try {
    const q = query.trim();
    if (q.length < 1) return { success: true, users: [] };
    const isUuid =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(q);
    let qb = supabaseAdmin.from("users").select("id, username, short_id, avatar_url").limit(20);
    if (isUuid) {
      qb = qb.eq("id", q);
    } else if (/^\d+$/.test(q)) {
      qb = qb.or(`short_id.eq.${q},username.ilike.%${q}%`);
    } else {
      qb = qb.ilike("username", `%${q}%`);
    }
    const { data, error } = await qb;
    if (error) throw error;
    return {
      success: true,
      users: (data || []).map((u) => ({
        id: u.id as string,
        username: String(u.username || "user"),
        short_id: u.short_id != null ? String(u.short_id) : null,
        avatar_url: u.avatar_url ? String(u.avatar_url) : null,
      })),
    };
  } catch (error: any) {
    console.error("searchUsersForShopGrant", error);
    return { success: false, error: error.message };
  }
}
const PERMANENT_EXPIRY = "9999-12-31T00:00:00.000Z";
export async function sendShopItemToUser(opts: {
  itemId: string;
  userId: string;
  durationDays: number;
  equip?: boolean;
}) {
  try {
    const { itemId, userId } = opts;
    const durationDays = Math.floor(Number(opts.durationDays) || 0);
    if (!itemId) throw new Error("Item required");
    if (!userId) throw new Error("User required");
    const { data: item, error: itemErr } = await supabaseAdmin
      .from("shop_items")
      .select("id, name, image_url, duration_days, shop_categories(name)")
      .eq("id", itemId)
      .maybeSingle();
    if (itemErr) throw itemErr;
    if (!item) throw new Error("Shop item not found");
    const { data: user, error: userErr } = await supabaseAdmin
      .from("users")
      .select("id, username, short_id")
      .eq("id", userId)
      .maybeSingle();
    if (userErr) throw userErr;
    if (!user) throw new Error("User not found");
    const now = Date.now();
    const addMs = durationDays > 0 ? durationDays * 24 * 60 * 60 * 1000 : null;
    const { data: existing } = await supabaseAdmin
      .from("user_inventory")
      .select("id, expires_at")
      .eq("user_id", userId)
      .eq("item_id", itemId)
      .maybeSingle();
    let expiresAt: string;
    if (addMs == null) {
      expiresAt = PERMANENT_EXPIRY;
    } else if (existing?.expires_at) {
      const current = new Date(existing.expires_at).getTime();
      const base = current > now ? current : now;
      expiresAt = new Date(base + addMs).toISOString();
    } else {
      expiresAt = new Date(now + addMs).toISOString();
    }
    let inventoryId = existing?.id as string | undefined;
    if (inventoryId) {
      const { error } = await supabaseAdmin
        .from("user_inventory")
        .update({ expires_at: expiresAt })
        .eq("id", inventoryId);
      if (error) throw error;
    } else {
      const baseRow = {
        user_id: userId,
        item_id: itemId,
        is_equipped: false,
        expires_at: expiresAt,
      };
      let inserted: {
        id: string;
      } | null = null;
      let error: {
        message?: string;
      } | null = null;
      ({ data: inserted, error } = await supabaseAdmin
        .from("user_inventory")
        .insert({ ...baseRow, source: "admin" })
        .select("id")
        .single());
      if (error && /source/i.test(error.message ?? "")) {
        ({ data: inserted, error } = await supabaseAdmin
          .from("user_inventory")
          .insert(baseRow)
          .select("id")
          .single());
      }
      if (error) throw error;
      inventoryId = inserted!.id;
    }
    if (opts.equip && inventoryId) {
      const catRaw = item.shop_categories as
        | {
            name?: string;
          }
        | {
            name?: string;
          }[]
        | null;
      const catName = Array.isArray(catRaw)
        ? (catRaw[0]?.name ?? "Unknown")
        : (catRaw?.name ?? "Unknown");
      const { error: rpcError } = await supabaseAdmin.rpc("equip_user_asset", {
        p_asset_id: inventoryId,
        p_user_id: userId,
        p_category_name: catName,
      });
      if (rpcError) {
        await supabaseAdmin
          .from("user_inventory")
          .update({ is_equipped: true })
          .eq("id", inventoryId)
          .eq("user_id", userId);
      }
    }
    const catRaw = item.shop_categories as
      | {
          name?: string;
        }
      | {
          name?: string;
        }[]
      | null;
    const categoryName = Array.isArray(catRaw)
      ? (catRaw[0]?.name ?? "Item")
      : (catRaw?.name ?? "Item");
    const durationLabel =
      durationDays > 0 ? `${durationDays} day${durationDays === 1 ? "" : "s"}` : "forever";
    const title = "Gift from SK Live";
    const content = `SK Live sent you "${item.name}" (${categoryName}) — yours for ${durationLabel}. Open Inventory to enjoy it!`;
    const { error: notifErr } = await supabaseAdmin.from("system_notifications").insert({
      user_id: userId,
      title,
      content,
      type: "admin_gift",
      icon_type: "gift",
      metadata: {
        item_id: itemId,
        item_name: item.name,
        category: categoryName,
        duration_days: durationDays,
        image_url: item.image_url || null,
        route: "/inventory",
        gift_from: "SK Live",
      },
    });
    if (notifErr) {
      console.error("admin gift notification insert failed:", notifErr);
    }
    revalidatePath("/shop");
    revalidatePath(`/users/${userId}`);
    return {
      success: true as const,
      message: `Sent "${item.name}" to @${user.username}${user.short_id ? ` (${user.short_id})` : ""} for ${durationDays > 0 ? `${durationDays} days` : "permanent"}${notifErr ? " (notification failed)" : " · notified"}`,
    };
  } catch (error: any) {
    console.error("sendShopItemToUser", error);
    return { success: false as const, error: error.message };
  }
}
