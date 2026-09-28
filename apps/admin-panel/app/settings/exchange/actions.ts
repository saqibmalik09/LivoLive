"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function updateExchangeConfig(id: string, data: any) {
  try {
    const { error } = await supabaseAdmin.from("exchange_configs").update(data).eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/exchange");
    revalidatePath(`/settings/exchange/${id}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error updating exchange config:", error);
    return { success: false, error: error.message };
  }
}
