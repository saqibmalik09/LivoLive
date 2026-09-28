"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function updateMedalConfig(id: string, data: any) {
  const { error } = await supabaseAdmin.from("shop_items").update(data).eq("id", id);
  if (error) throw error;
  revalidatePath("/settings/levels/medals");
  return { success: true };
}
