"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function upsertCategory(data: any) {
  try {
    const { id, ...updateData } = data;
    let res;
    if (id) {
      res = await supabaseAdmin.from("shop_categories").update(updateData).eq("id", id);
    } else {
      res = await supabaseAdmin.from("shop_categories").insert(updateData);
    }
    if (res.error) throw res.error;
    revalidatePath("/shop");
    return { success: true };
  } catch (error: any) {
    console.error("Error upserting category:", error);
    return { success: false, error: error.message };
  }
}
export async function deleteCategory(id: string) {
  try {
    const { count } = await supabaseAdmin
      .from("shop_items")
      .select("*", { count: "exact", head: true })
      .eq("category_id", id);
    if (count && count > 0) {
      return {
        success: false,
        error: "Cannot delete category that contains items. Move items first.",
      };
    }
    const { error } = await supabaseAdmin.from("shop_categories").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/shop");
    return { success: true };
  } catch (error: any) {
    console.error("Error deleting category:", error);
    return { success: false, error: error.message };
  }
}
