import type { User } from "@supabase/supabase-js";
import { supabase } from "./supabase";

export type SkWebViewSession = {
  access_token?: string;
  gateway?: string;
};

declare global {
  interface Window {
    __SK_SESSION?: SkWebViewSession;
  }
}

export function readWebViewAccessToken(): string | null {
  if (typeof window === "undefined") return null;

  try {
    const fromUrl = new URLSearchParams(window.location.search)
      .get("token")
      ?.trim();
    if (fromUrl) return fromUrl;
  } catch {
    // ignore
  }

  const fromInject = window.__SK_SESSION?.access_token?.trim();
  if (fromInject) return fromInject;

  return null;
}

export async function waitForWebViewAccessToken(opts?: {
  timeoutMs?: number;
}): Promise<string | null> {
  const existing = readWebViewAccessToken();
  if (existing) return existing;
  if (typeof window === "undefined") return null;

  const timeoutMs = Math.max(0, opts?.timeoutMs ?? 10_000);

  return new Promise((resolve) => {
    let settled = false;

    const finish = (token: string | null) => {
      if (settled) return;
      settled = true;
      window.clearInterval(poll);
      window.clearTimeout(timer);
      window.removeEventListener("sklive-auth", onAuth as EventListener);
      resolve(token);
    };

    const onAuth = (ev: Event) => {
      const detail = (ev as CustomEvent<SkWebViewSession>).detail;
      const t =
        detail?.access_token?.trim() ||
        window.__SK_SESSION?.access_token?.trim() ||
        null;
      if (t) finish(t);
    };

    window.addEventListener("sklive-auth", onAuth as EventListener);

    const poll = window.setInterval(() => {
      const t = readWebViewAccessToken();
      if (t) finish(t);
    }, 50);

    const timer = window.setTimeout(() => {
      finish(readWebViewAccessToken());
    }, timeoutMs);
  });
}

export async function applyWebViewAccessToken(
  accessToken?: string | null,
): Promise<User | null> {
  let token = accessToken?.trim() || null;
  if (!token) {
    token = await waitForWebViewAccessToken({ timeoutMs: 10_000 });
  }
  if (!token) return null;

  const { data, error } = await supabase.auth.setSession({
    access_token: token,
    refresh_token: "webview-no-refresh",
  });

  try {
    supabase.auth.stopAutoRefresh();
  } catch {
    // ignore
  }

  if (error) {
    console.error("[webview-auth] setSession failed:", error.message);
    return null;
  }

  return data.user ?? null;
}

export async function applyWebViewSessionFromHost(): Promise<User | null> {
  return applyWebViewAccessToken(null);
}
