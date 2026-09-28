"use server";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
const COOKIE_NAME = "admin_session";
const COOKIE_MAX_AGE = 86400;
export async function adminLoginAction(formData: FormData) {
  const password = String(formData.get("password") ?? "");
  const expected = process.env.ADMIN_PANEL_PASSWORD?.trim() || "";
  if (!expected) {
    return {
      success: false as const,
      error: "Admin password is not configured on the server",
    };
  }
  if (!password || password !== expected) {
    return { success: false as const, error: "Invalid password" };
  }
  const jar = await cookies();
  jar.set(COOKIE_NAME, "authenticated", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: COOKIE_MAX_AGE,
  });
  redirect("/");
}
