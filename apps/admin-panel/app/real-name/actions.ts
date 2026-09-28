"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export async function reviewRealNameApplication(formData: FormData) {
  const id = String(formData.get("id") || "").trim();
  const approve = String(formData.get("approve") || "") === "1";
  const reject_reason = String(formData.get("reject_reason") || "").trim() || null;
  if (!id) throw new Error("id required");
  const { error } = await supabaseAdmin
    .from("real_name_applications")
    .update({
      status: approve ? "approved" : "rejected",
      step5_done: approve,
      reviewed_at: new Date().toISOString(),
      reject_reason: approve ? null : reject_reason || "Rejected",
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);
  if (error) throw new Error(error.message);
  await logAdminAction({
    action: "real_name.review",
    targetType: "real_name_application",
    targetId: id,
    summary: `${approve ? "Approved" : "Rejected"} real-name KYC`,
    metadata: { approved: approve, reject_reason },
  });
  revalidatePath("/real-name");
  revalidatePath(`/real-name/${id}`);
}
