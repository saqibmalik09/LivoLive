import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Inline Zego Token04 (no npm dependency — Supabase bundler cannot fetch
 * zego-server-assistant from esm.sh).
 * Spec matches ZEGOCLOUD/zego_server_assistant token/nodejs.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function rndNum(a: number, b: number): number {
  return Math.ceil((a + (b - a) * Math.random()));
}

function makeRandomIv(): string {
  const str = "0123456789abcdefghijklmnopqrstuvwxyz";
  let result = "";
  for (let i = 0; i < 16; i++) {
    result += str.charAt(Math.floor(Math.random() * str.length));
  }
  return result;
}

function getAlgorithm(keyLen: number): string {
  switch (keyLen) {
    case 16:
      return "aes-128-cbc";
    case 24:
      return "aes-192-cbc";
    case 32:
      return "aes-256-cbc";
    default:
      throw new Error(`Invalid key length: ${keyLen}`);
  }
}

async function aesEncrypt(
  plainText: string,
  key: string,
  iv: string,
): Promise<Uint8Array> {
  const keyBytes = new TextEncoder().encode(key);
  const ivBytes = new TextEncoder().encode(iv);
  const algoName = getAlgorithm(keyBytes.length);

  // WebCrypto only exposes AES-CBC; map aes-*-cbc → AES-CBC with key length.
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-CBC" },
    false,
    ["encrypt"],
  );
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv: ivBytes },
    cryptoKey,
    new TextEncoder().encode(plainText),
  );
  // Silence unused for Deno lint if algo mapping changes.
  void algoName;
  return new Uint8Array(encrypted);
}

function concatBytes(...parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    out.set(p, offset);
    offset += p.length;
  }
  return out;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary);
}

async function generateToken04(
  appId: number,
  userId: string,
  secret: string,
  effectiveTimeInSeconds: number,
  payload: string,
): Promise<string> {
  if (!appId || typeof appId !== "number") {
    throw new Error("appID invalid");
  }
  if (!userId || typeof userId !== "string") {
    throw new Error("userId invalid");
  }
  if (!secret || typeof secret !== "string" || secret.length !== 32) {
    throw new Error("secret must be a 32 byte string");
  }
  if (!effectiveTimeInSeconds || typeof effectiveTimeInSeconds !== "number") {
    throw new Error("effectiveTimeInSeconds invalid");
  }

  const createTime = Math.floor(Date.now() / 1000);
  const tokenInfo = {
    app_id: appId,
    user_id: userId,
    nonce: rndNum(-2147483648, 2147483647),
    ctime: createTime,
    expire: createTime + effectiveTimeInSeconds,
    payload: payload || "",
  };

  const plainText = JSON.stringify(tokenInfo);
  const iv = makeRandomIv();
  const encryptBuf = await aesEncrypt(plainText, secret, iv);

  const b1 = new Uint8Array(8);
  new DataView(b1.buffer).setBigInt64(0, BigInt(tokenInfo.expire), false);
  const b2 = new Uint8Array(2);
  new DataView(b2.buffer).setUint16(0, iv.length, false);
  const b3 = new Uint8Array(2);
  new DataView(b3.buffer).setUint16(0, encryptBuf.byteLength, false);

  const buf = concatBytes(
    b1,
    b2,
    new TextEncoder().encode(iv),
    b3,
    encryptBuf,
  );

  return "04" + bytesToBase64(buf);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return jsonResponse({ success: false, message: "Missing auth" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!supabaseUrl || !anonKey) {
      return jsonResponse({ success: false, message: "Server misconfigured" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return jsonResponse({ success: false, message: "Not authenticated" }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const roomId = String(body.room_id || body.roomId || "").trim();
    const userId = user.id;

    const appId = Number(Deno.env.get("ZEGO_APP_ID") || "0");
    const serverSecret = (Deno.env.get("ZEGO_SERVER_SECRET") || "").trim();
    if (!appId || serverSecret.length !== 32) {
      return jsonResponse(
        {
          success: false,
          message:
            "ZEGO_APP_ID / ZEGO_SERVER_SECRET not configured (32-char ServerSecret)",
        },
        500,
      );
    }

    const effectiveTimeInSeconds = 3600;
    const payload = roomId
      ? JSON.stringify({
        room_id: roomId,
        privilege: { 1: 1, 2: 1 },
        stream_id_list: null,
      })
      : "";

    const token = await generateToken04(
      appId,
      userId,
      serverSecret,
      effectiveTimeInSeconds,
      payload,
    );

    return jsonResponse({
      success: true,
      app_id: appId,
      token,
      user_id: userId,
      expire_seconds: effectiveTimeInSeconds,
    });
  } catch (e) {
    console.error("[zego-token]", e);
    return jsonResponse(
      { success: false, message: e instanceof Error ? e.message : "Token failed" },
      500,
    );
  }
});
