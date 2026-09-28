"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function updateVipPlan(id: string, data: any) {
  try {
    const { error } = await supabaseAdmin.from("vip_plans").update(data).eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/vip");
    revalidatePath(`/settings/vip/${id}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error updating VIP plan:", error);
    return { success: false, error: error.message };
  }
}
