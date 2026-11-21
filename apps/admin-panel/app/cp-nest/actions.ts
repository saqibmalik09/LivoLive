"use server";
import { randomUUID } from "crypto";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
function safeStorageObjectKey(folder: string, originalName: string, fallbackExt: string) {
  const rawExt = originalName.includes(".")
    ? originalName.split(".").pop()?.toLowerCase()
    : fallbackExt;
  const ext = (rawExt || fallbackExt).replace(/[^a-z0-9]/gi, "") || fallbackExt;
  return `${folder}${Date.now()}-${randomUUID().slice(0, 8)}.${ext}`;
}
export async function upsertCPNestItem(data: {
  id?: string;
  name: string;
  price: number;
  image_url?: string | null;
  svga_url?: string | null;
  category?: string | null;
}) {
  try {
    const { id, name, price, image_url, svga_url, category } = data;
    const row = {
      name,
      price,
      image_url: image_url || null,
      svga_url: svga_url || null,
      category: category || null,
    };
    let res;
    if (id) {
      res = await supabaseAdmin.from("cp_nest_items").update(row).eq("id", id);
    } else {
      res = await supabaseAdmin.from("cp_nest_items").insert(row);
    }
    if (res.error) throw res.error;
    revalidatePath("/cp-nest");
    if (id) revalidatePath(`/cp-nest/${id}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error upserting CP nest item:", error);
    return { success: false, error: error.message };
  }
}
export async function uploadCPNestImage(formData: FormData) {
  return uploadCPNestAsset(formData, "image");
}
export async function uploadCPNestSvga(formData: FormData) {
  return uploadCPNestAsset(formData, "svga");
}
async function uploadCPNestAsset(formData: FormData, kind: "image" | "svga") {
  try {
    const file = formData.get("file") as File;
    if (!file) throw new Error("No file provided");
    const isSvga = kind === "svga" || file.name.toLowerCase().endsWith(".svga");
    const folder = isSvga ? "svga/" : "images/";
    const fileName = safeStorageObjectKey(folder, file.name, isSvga ? "svga" : "png");
    const buffer = Buffer.from(await file.arrayBuffer());
    const contentType = isSvga ? "application/octet-stream" : file.type || "image/png";
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "cp_nest_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    return { success: true, url: publicUrl };
  } catch (error: any) {
    console.error("Error uploading CP nest asset:", error);
    return { success: false, error: error.message };
  }
}
export async function deleteCPNestItem(id: string) {
  try {
    const { error } = await supabaseAdmin.from("cp_nest_items").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/cp-nest");
    return { success: true };
  } catch (error: any) {
    console.error("Error deleting CP nest item:", error);
    return { success: false, error: error.message };
  }
}
