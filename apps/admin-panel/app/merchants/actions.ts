"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { logAdminAction, auditUserLabel } from "@/lib/admin-audit";
import {
  hashPassword,
  normalizeMasterUsername,
  isValidMasterUsername,
  isValidMasterPassword,
} from "@/lib/master-password";
import { revalidatePath } from "next/cache";

type Result = { success: boolean; error?: string; message?: string };

function revalidateMerchants(userId?: string) {
  revalidatePath("/merchants");
  if (userId) revalidatePath(`/merchants/${userId}`);
}

/** Unwrap the `{ success, message }` json every merchant RPC returns. */
function unwrap(data: unknown, error: { message: string } | null): Result {
  if (error) return { success: false, error: error.message };
  const row = data as { success?: boolean; message?: string } | null;
  if (!row || row.success !== true) {
    return { success: false, error: row?.message ?? "Operation failed" };
  }
  return { success: true, message: row.message };
}

/** Find any user by numeric ID or name, to promote to merchant. */
export async function searchUsersForMerchant(query: string) {
  const q = query.trim();
  if (!q) return { success: true, users: [] as Record<string, unknown>[] };
  const { data, error } = await supabaseAdmin.rpc("admin_search_users_for_merchant", {
    p_query: q,
    p_limit: 20,
  });
  if (error) return { success: false, error: error.message, users: [] };
  return { success: true, users: (data as Record<string, unknown>[]) ?? [] };
}

/** Promote any ID to merchant, or revoke merchant access. */
export async function setMerchant(
  userId: string,
  enabled: boolean,
  opts: {
    commissionPercent?: number;
    coinsPerUsd?: number;
    creditLimit?: number;
    displayName?: string;
    contact?: string;
    notes?: string;
  } = {},
): Promise<Result> {
  const { data, error } = await supabaseAdmin.rpc("admin_set_merchant", {
    p_user_id: userId,
    p_enabled: enabled,
    p_commission_percent: opts.commissionPercent ?? null,
    p_coins_per_usd: opts.coinsPerUsd ?? null,
    p_credit_limit: opts.creditLimit ?? null,
    p_display_name: opts.displayName ?? null,
    p_contact: opts.contact ?? null,
    p_notes: opts.notes ?? null,
    p_actor_id: null,
  });
  const res = unwrap(data, error);

  await logAdminAction({
    action: enabled ? "merchant.enable" : "merchant.disable",
    targetType: "user",
    targetId: userId,
    summary: `${enabled ? "Granted" : "Revoked"} merchant access for ${await auditUserLabel(userId)}`,
    metadata: { ...opts, enabled },
    success: res.success,
  });

  revalidateMerchants(userId);
  return res;
}

/** Edit a merchant's commission, rate, credit limit and details. */
export async function updateMerchant(
  userId: string,
  opts: {
    commissionPercent?: number;
    coinsPerUsd?: number;
    creditLimit?: number;
    displayName?: string;
    contact?: string;
    notes?: string;
  },
): Promise<Result> {
  const { data, error } = await supabaseAdmin.rpc("admin_update_merchant", {
    p_user_id: userId,
    p_commission_percent: opts.commissionPercent ?? null,
    p_coins_per_usd: opts.coinsPerUsd ?? null,
    p_credit_limit: opts.creditLimit ?? null,
    p_display_name: opts.displayName ?? null,
    p_contact: opts.contact ?? null,
    p_notes: opts.notes ?? null,
  });
  const res = unwrap(data, error);

  await logAdminAction({
    action: "merchant.update",
    targetType: "user",
    targetId: userId,
    summary: `Updated merchant settings for ${await auditUserLabel(userId)}`,
    metadata: opts,
    success: res.success,
  });

  revalidateMerchants(userId);
  return res;
}

/** Block or unblock a merchant. Balance and history are preserved. */
export async function blockMerchant(
  userId: string,
  blocked: boolean,
  reason?: string,
): Promise<Result> {
  const { data, error } = await supabaseAdmin.rpc("admin_block_merchant", {
    p_user_id: userId,
    p_blocked: blocked,
    p_reason: reason ?? null,
    p_actor_id: null,
  });
  const res = unwrap(data, error);

  await logAdminAction({
    action: blocked ? "merchant.block" : "merchant.unblock",
    targetType: "user",
    targetId: userId,
    summary: `${blocked ? "Blocked" : "Unblocked"} merchant ${await auditUserLabel(userId)}${
      blocked && reason ? ` — ${reason}` : ""
    }`,
    metadata: { blocked, reason: reason ?? null },
    success: res.success,
  });

  revalidateMerchants(userId);
  return res;
}

/**
 * Recharge (positive) or remove (negative) merchant coins.
 * Recorded in merchant_ledger, so the merchant sees it in-app too.
 */
export async function adjustMerchantCoins(
  userId: string,
  amount: number,
  note?: string,
): Promise<Result> {
  if (!Number.isFinite(amount) || amount === 0) {
    return { success: false, error: "Amount must not be zero" };
  }
  const { data, error } = await supabaseAdmin.rpc("admin_adjust_merchant_coins", {
    p_user_id: userId,
    p_amount: Math.trunc(amount),
    p_note: note ?? null,
    p_actor_id: null,
  });
  const res = unwrap(data, error);

  await logAdminAction({
    action: amount > 0 ? "merchant.recharge" : "merchant.deduct",
    targetType: "user",
    targetId: userId,
    summary: `${amount > 0 ? "Recharged" : "Removed"} ${Math.abs(
      Math.trunc(amount),
    ).toLocaleString()} coins ${amount > 0 ? "to" : "from"} merchant ${await auditUserLabel(userId)}`,
    metadata: { amount: Math.trunc(amount), note: note ?? null },
    success: res.success,
  });

  revalidateMerchants(userId);
  return res;
}

/** Approve, reject or settle a merchant withdrawal request. */
export async function processMerchantWithdrawal(
  withdrawalId: string,
  status: "approved" | "rejected" | "paid",
  adminNote?: string,
  merchantUserId?: string,
): Promise<Result> {
  const { data, error } = await supabaseAdmin.rpc("admin_process_merchant_withdrawal", {
    p_withdrawal_id: withdrawalId,
    p_status: status,
    p_admin_note: adminNote ?? null,
    p_actor_id: null,
  });
  const res = unwrap(data, error);

  await logAdminAction({
    action: `merchant.withdrawal.${status}`,
    targetType: "merchant_withdrawal",
    targetId: withdrawalId,
    summary: `Merchant withdrawal ${status}`,
    metadata: { status, adminNote: adminNote ?? null },
    success: res.success,
  });

  revalidateMerchants(merchantUserId);
  revalidatePath("/withdrawals");
  return res;
}

// ── Merchant panel credentials ──────────────────────────────────────
// The merchant web panel (merchant.skliveparty.online) uses its own
// username/password, issued here. App accounts are often social logins
// with no password, and panel access must be revocable on its own.

/** Issue or replace a merchant's panel login. */
export async function grantMerchantLogin(
  userId: string,
  usernameRaw: string,
  password: string,
): Promise<Result & { username?: string }> {
  const username = normalizeMasterUsername(usernameRaw);
  if (!isValidMasterUsername(username)) {
    return {
      success: false,
      error: "Username must be 3–32 characters: lowercase letters, numbers or underscore",
    };
  }
  if (!isValidMasterPassword(password)) {
    return { success: false, error: "Password must be 8–128 characters" };
  }

  const { data: u } = await supabaseAdmin
    .from("users")
    .select("is_merchant")
    .eq("id", userId)
    .maybeSingle();
  if (!u || u.is_merchant !== true) {
    return { success: false, error: "User is not a merchant" };
  }

  // Refuse a username already issued to a different merchant.
  const { data: clash } = await supabaseAdmin
    .from("merchant_panel_logins")
    .select("user_id")
    .eq("username", username)
    .maybeSingle();
  if (clash && clash.user_id !== userId) {
    return { success: false, error: "That username is already taken" };
  }

  const { error } = await supabaseAdmin.from("merchant_panel_logins").upsert(
    {
      user_id: userId,
      username,
      password_hash: hashPassword(password),
      is_active: true,
      must_change_password: true,
      failed_attempts: 0,
      locked_until: null,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id" },
  );
  if (error) return { success: false, error: error.message };

  // Any existing panel session is ended, so an old password cannot linger.
  await supabaseAdmin
    .from("merchant_panel_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .is("revoked_at", null)
    .in(
      "login_id",
      (
        await supabaseAdmin
          .from("merchant_panel_logins")
          .select("id")
          .eq("user_id", userId)
      ).data?.map((r) => r.id) ?? [],
    );

  await logAdminAction({
    action: "merchant.login.grant",
    targetType: "user",
    targetId: userId,
    summary: `Issued merchant panel login @${username} for ${await auditUserLabel(userId)}`,
    metadata: { username },
    success: true,
  });

  revalidateMerchants(userId);
  return { success: true, message: "Panel login issued", username };
}

/** Enable or disable panel access without deleting the credentials. */
export async function setMerchantLoginActive(
  userId: string,
  active: boolean,
): Promise<Result> {
  const { data: login } = await supabaseAdmin
    .from("merchant_panel_logins")
    .select("id")
    .eq("user_id", userId)
    .maybeSingle();
  if (!login) return { success: false, error: "No panel login for this merchant" };

  const { error } = await supabaseAdmin
    .from("merchant_panel_logins")
    .update({
      is_active: active,
      failed_attempts: 0,
      locked_until: null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", login.id);
  if (error) return { success: false, error: error.message };

  if (!active) {
    await supabaseAdmin
      .from("merchant_panel_sessions")
      .update({ revoked_at: new Date().toISOString() })
      .eq("login_id", login.id)
      .is("revoked_at", null);
  }

  await logAdminAction({
    action: active ? "merchant.login.enable" : "merchant.login.disable",
    targetType: "user",
    targetId: userId,
    summary: `${active ? "Enabled" : "Disabled"} merchant panel access for ${await auditUserLabel(userId)}`,
    success: true,
  });

  revalidateMerchants(userId);
  return { success: true, message: active ? "Panel access enabled" : "Panel access disabled" };
}

/** Sign the merchant out of the web panel everywhere. */
export async function revokeMerchantSessions(userId: string): Promise<Result> {
  const { data: login } = await supabaseAdmin
    .from("merchant_panel_logins")
    .select("id")
    .eq("user_id", userId)
    .maybeSingle();
  if (!login) return { success: false, error: "No panel login for this merchant" };

  const { error } = await supabaseAdmin
    .from("merchant_panel_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("login_id", login.id)
    .is("revoked_at", null);
  if (error) return { success: false, error: error.message };

  await logAdminAction({
    action: "merchant.login.revoke_sessions",
    targetType: "user",
    targetId: userId,
    summary: `Signed out merchant panel sessions for ${await auditUserLabel(userId)}`,
    success: true,
  });

  revalidateMerchants(userId);
  return { success: true, message: "Signed out of the panel everywhere" };
}
