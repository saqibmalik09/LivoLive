"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function addRechargePackage(data: any) {
  try {
    const { error } = await supabaseAdmin.from("recharge_packages").insert(data);
    if (error) throw error;
    revalidatePath("/recharge");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function updateRechargePackage(id: string, data: any) {
  try {
    const { error } = await supabaseAdmin.from("recharge_packages").update(data).eq("id", id);
    if (error) throw error;
    revalidatePath("/recharge");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function deleteRechargePackage(id: string) {
  try {
    const { error } = await supabaseAdmin.from("recharge_packages").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/recharge");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
