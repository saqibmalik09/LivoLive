"use server";

import { redirect } from "next/navigation";
import { headers } from "next/headers";
import { supabaseAdmin } from "@/lib/supabase";
import {
  normalizeUsername,
  verifyPassword,
  hashPassword,
  isValidPassword,
} from "@/lib/merchant-password";
import {
  createSession,
  destroySession,
  getMerchantActor,
  revokeOtherSessions,
} from "@/lib/merchant-session";

const MAX_ATTEMPTS = 8;
const LOCK_MINUTES = 15;

export async function loginAction(_prev: unknown, formData: FormData) {
  const username = normalizeUsername(String(formData.get("username") ?? ""));
  const password = String(formData.get("password") ?? "");

  if (!username || !password) {
    return { error: "Enter your username and password" };
  }

  const { data: login, error } = await supabaseAdmin
    .from("merchant_panel_logins")
    .select(
      "id, user_id, username, password_hash, is_active, failed_attempts, locked_until",
    )
    .eq("username", username)
    .maybeSingle();

  if (error) {
    console.error("[merchant login]", error.message);
    return { error: "Login failed, please try again" };
  }

  // Same message whether the username exists or not, so the form cannot be
  // used to discover valid merchant usernames.
  const GENERIC = "Invalid username or password";
  if (!login || !login.is_active) return { error: GENERIC };

  if (login.locked_until && new Date(login.locked_until).getTime() > Date.now()) {
    const mins = Math.max(
      1,
      Math.ceil((new Date(login.locked_until).getTime() - Date.now()) / 60000),
    );
    return { error: `Too many attempts. Try again in ${mins} minute(s).` };
  }

  if (!verifyPassword(password, login.password_hash)) {
    const attempts = (login.failed_attempts ?? 0) + 1;
    await supabaseAdmin
      .from("merchant_panel_logins")
      .update({
        failed_attempts: attempts,
        locked_until:
          attempts >= MAX_ATTEMPTS
            ? new Date(Date.now() + LOCK_MINUTES * 60000).toISOString()
            : null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", login.id);
    return { error: GENERIC };
  }

  // The panel is only useful while the account is still an active merchant.
  const { data: u } = await supabaseAdmin
    .from("users")
    .select("is_merchant")
    .eq("id", login.user_id)
    .maybeSingle();
  if (!u || u.is_merchant !== true) {
    return { error: "This account no longer has merchant access." };
  }

  const hdrs = await headers();
  await supabaseAdmin
    .from("merchant_panel_logins")
    .update({
      failed_attempts: 0,
      locked_until: null,
      last_login_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", login.id);

  await createSession(login.id, {
    ip: hdrs.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null,
    userAgent: hdrs.get("user-agent"),
  });

  redirect("/");
}

export async function logoutAction() {
  await destroySession();
  redirect("/login");
}

export async function changePasswordAction(_prev: unknown, formData: FormData) {
  const actor = await getMerchantActor();
  if (!actor) redirect("/login");

  const current = String(formData.get("current") ?? "");
  const next = String(formData.get("next") ?? "");
  const confirm = String(formData.get("confirm") ?? "");

  if (next !== confirm) return { error: "The new passwords do not match" };
  if (!isValidPassword(next)) {
    return { error: "New password must be 8–128 characters" };
  }
  if (next === current) {
    return { error: "Choose a password different from your current one" };
  }

  const { data: login } = await supabaseAdmin
    .from("merchant_panel_logins")
    .select("id, password_hash")
    .eq("id", actor.loginId)
    .maybeSingle();

  if (!login || !verifyPassword(current, login.password_hash)) {
    return { error: "Your current password is incorrect" };
  }

  const { error } = await supabaseAdmin
    .from("merchant_panel_logins")
    .update({
      password_hash: hashPassword(next),
      must_change_password: false,
      updated_at: new Date().toISOString(),
    })
    .eq("id", actor.loginId);

  if (error) return { error: "Could not update the password" };

  // Anyone else holding a session for this login is signed out.
  await revokeOtherSessions(actor.loginId);
  return { ok: "Password updated" };
}
