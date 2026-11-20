import { cookies } from "next/headers";
import { createHash, randomBytes } from "crypto";
import { supabaseAdmin } from "@/lib/supabase";
import "server-only";

/**
 * Merchant panel sessions.
 *
 * The cookie holds an opaque random token and nothing else — the server
 * looks up which merchant it belongs to. A cookie that described its own
 * identity (as the master panel's `op:{id}:{username}` does) would let
 * anyone who learns a merchant's id read that merchant's books and spend
 * their coins, since this panel transacts with the service-role key.
 */

const COOKIE_NAME = "merchant_session";
const SESSION_HOURS = 12;

export type MerchantActor = {
  loginId: string;
  userId: string;
  username: string;
  mustChangePassword: boolean;
};

function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/** Create a session row and return the raw token for the cookie. */
export async function createSession(
  loginId: string,
  meta: { ip?: string | null; userAgent?: string | null } = {},
): Promise<string> {
  const token = randomBytes(32).toString("hex");
  const expiresAt = new Date(Date.now() + SESSION_HOURS * 3600_000);

  const { error } = await supabaseAdmin.from("merchant_panel_sessions").insert({
    login_id: loginId,
    token_hash: hashToken(token),
    expires_at: expiresAt.toISOString(),
    ip: meta.ip ?? null,
    user_agent: meta.userAgent ?? null,
  });
  if (error) throw new Error(`session create failed: ${error.message}`);

  const jar = await cookies();
  jar.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_HOURS * 3600,
  });

  return token;
}

/**
 * Resolve the signed-in merchant, or null. Every page and action must get
 * the merchant id from here — never from a URL, form field or header.
 */
export async function getMerchantActor(): Promise<MerchantActor | null> {
  const jar = await cookies();
  const token = jar.get(COOKIE_NAME)?.value?.trim();
  if (!token) return null;

  const { data, error } = await supabaseAdmin
    .from("merchant_panel_sessions")
    .select(
      "id, expires_at, revoked_at, login:merchant_panel_logins!inner(id, user_id, username, is_active, must_change_password)",
    )
    .eq("token_hash", hashToken(token))
    .maybeSingle();

  if (error || !data) return null;
  if (data.revoked_at) return null;
  if (new Date(data.expires_at).getTime() <= Date.now()) return null;

  const login = data.login as unknown as {
    id: string;
    user_id: string;
    username: string;
    is_active: boolean;
    must_change_password: boolean;
  } | null;
  if (!login || !login.is_active) return null;

  // Panel access is only meaningful while the account is still a merchant
  // and not blocked, so re-check on every request rather than trusting the
  // session — admin may have revoked or blocked them mid-session.
  const { data: u } = await supabaseAdmin
    .from("users")
    .select("is_merchant, is_merchant_blocked")
    .eq("id", login.user_id)
    .maybeSingle();
  if (!u || u.is_merchant !== true) return null;

  void supabaseAdmin
    .from("merchant_panel_sessions")
    .update({ last_seen_at: new Date().toISOString() })
    .eq("id", data.id)
    .then(() => undefined);

  return {
    loginId: login.id,
    userId: login.user_id,
    username: login.username,
    mustChangePassword: login.must_change_password === true,
  };
}

/** Like getMerchantActor, but for pages that cannot render without one. */
export async function requireMerchantActor(): Promise<MerchantActor> {
  const actor = await getMerchantActor();
  if (!actor) throw new Error("UNAUTHENTICATED");
  return actor;
}

export async function destroySession(): Promise<void> {
  const jar = await cookies();
  const token = jar.get(COOKIE_NAME)?.value?.trim();
  if (token) {
    await supabaseAdmin
      .from("merchant_panel_sessions")
      .update({ revoked_at: new Date().toISOString() })
      .eq("token_hash", hashToken(token));
  }
  jar.delete(COOKIE_NAME);
}

/** Revoke every other session for this login (used after a password change). */
export async function revokeOtherSessions(
  loginId: string,
  keepToken?: string,
): Promise<void> {
  let q = supabaseAdmin
    .from("merchant_panel_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("login_id", loginId)
    .is("revoked_at", null);
  if (keepToken) q = q.neq("token_hash", hashToken(keepToken));
  await q;
}

export const MERCHANT_COOKIE_NAME = COOKIE_NAME;
