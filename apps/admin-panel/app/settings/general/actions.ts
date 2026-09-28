"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function updateSystemSetting(key: string, value: string) {
  try {
    const trimmed = value.trim();
    const { data, error } = await supabaseAdmin
      .from("system_settings")
      .update({ value: trimmed, updated_at: new Date().toISOString() })
      .eq("key", key)
      .select("key");
    if (error) throw error;
    if (!data?.length) {
      const { error: insertError } = await supabaseAdmin.from("system_settings").insert({
        key,
        value: trimmed,
        description:
          key === "invite_download_url"
            ? "Invite Friends share link. Shown when users tap Invite / share their invitation code."
            : null,
        updated_at: new Date().toISOString(),
      });
      if (insertError) throw insertError;
    }
    revalidatePath("/settings/general");
    return { success: true };
  } catch (error: any) {
    console.error("Error updating system setting:", error);
    return { success: false, error: error.message };
  }
}
