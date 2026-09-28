"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export async function replyToSupportTicket(ticketId: string, reply: string) {
  try {
    const { data, error } = await supabaseAdmin
      .from("support_messages")
      .update({
        admin_reply: reply,
        status: "resolved",
        replied_at: new Date().toISOString(),
      })
      .eq("id", ticketId)
      .select();
    if (error) throw error;
    revalidatePath("/messages");
    return { success: true, data };
  } catch (error: any) {
    console.error("Error replying to ticket:", error);
    return { success: false, error: error.message };
  }
}
export async function sendSystemNotification(title: string, content: string, userId?: string) {
  try {
    const { data, error } = await supabaseAdmin
      .from("system_notifications")
      .insert({
        title,
        content,
        user_id: userId || null,
        type: "system",
        icon_type: "notifications",
      })
      .select();
    if (error) throw error;
    revalidatePath("/messages");
    return { success: true, data };
  } catch (error: any) {
    console.error("Error sending notification:", error);
    return { success: false, error: error.message };
  }
}
