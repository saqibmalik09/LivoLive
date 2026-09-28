import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.11.1/index.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id?: string;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function loadServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  if (!raw?.trim()) {
    throw new Error("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not set");
  }
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error("Invalid GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  }
  return parsed;
}

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const privateKey = await jose.importPKCS8(
    sa.private_key.replace(/\\n/g, "\n"),
    "RS256",
  );

  const jwt = await new jose.SignJWT({
    scope: "https://www.googleapis.com/auth/androidpublisher",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setExpirationTime("1h")
    .setIssuedAt()
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok || !data.access_token) {
    console.error("Google OAuth failed", data);
    throw new Error("Failed to obtain Google Play access token");
  }
  return data.access_token as string;
}

/** Google Play product purchase (one-time / consumable). */
type PlayProductPurchase = {
  purchaseState?: number;
  consumptionState?: number;
  orderId?: string;
  productId?: string;
  purchaseToken?: string;
  acknowledgementState?: number;
};

async function verifyPlayProductPurchase(opts: {
  accessToken: string;
  packageName: string;
  productId: string;
  purchaseToken: string;
}): Promise<PlayProductPurchase> {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(opts.packageName)}/purchases/products/` +
    `${encodeURIComponent(opts.productId)}/tokens/` +
    `${encodeURIComponent(opts.purchaseToken)}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${opts.accessToken}` },
  });
  const data = await res.json();
  if (!res.ok) {
    console.error("Play verify failed", res.status, data);
    throw new Error(
      typeof data?.error?.message === "string"
        ? data.error.message
        : "Purchase could not be verified with Google Play",
    );
  }
  return data as PlayProductPurchase;
}

async function acknowledgePlayPurchase(opts: {
  accessToken: string;
  packageName: string;
  productId: string;
  purchaseToken: string;
}): Promise<void> {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(opts.packageName)}/purchases/products/` +
    `${encodeURIComponent(opts.productId)}/tokens/` +
    `${encodeURIComponent(opts.purchaseToken)}:acknowledge`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${opts.accessToken}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  if (!res.ok && res.status !== 400) {
    // 400 often means already acknowledged — non-fatal after credit
    const data = await res.json().catch(() => ({}));
    console.warn("Play acknowledge warning", res.status, data);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse({ success: false, message: "Method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return jsonResponse({ success: false, message: "Missing auth" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceKey) {
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

    const body = await req.json();
    const productId = String(body.productId ?? body.p_product_id ?? "").trim();
    const purchaseId = String(body.purchaseId ?? body.p_purchase_id ?? "").trim();
    const purchaseToken = String(
      body.purchaseToken ?? body.p_purchase_token ?? "",
    ).trim();

    if (!productId) {
      return jsonResponse({ success: false, message: "Invalid product" }, 400);
    }
    if (!purchaseToken || purchaseToken.length < 20) {
      return jsonResponse(
        { success: false, message: "Invalid purchase token" },
        400,
      );
    }

    const packageName =
      Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")?.trim() || "com.sklive.app";

    const sa = loadServiceAccount();
    const accessToken = await getGoogleAccessToken(sa);
    const play = await verifyPlayProductPurchase({
      accessToken,
      packageName,
      productId,
      purchaseToken,
    });

    // 0 = Purchased, 1 = Canceled, 2 = Pending
    if (play.purchaseState !== 0) {
      return jsonResponse({
        success: false,
        message: `Purchase not completed (state=${play.purchaseState})`,
      }, 400);
    }

    const googleOrderId = String(play.orderId ?? "").trim();
    if (!googleOrderId) {
      return jsonResponse({
        success: false,
        message: "Google Play returned no order id",
      }, 400);
    }

    // Prefer Google orderId; reject obvious client spoof of a different GPA id.
    if (purchaseId && purchaseId !== googleOrderId) {
      console.warn("purchaseId mismatch", { purchaseId, googleOrderId, user: user.id });
      return jsonResponse({
        success: false,
        message: "Purchase id does not match Google Play order",
      }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data, error } = await admin.rpc("deliver_iap_purchase", {
      p_product_id: productId,
      p_purchase_id: googleOrderId,
      p_purchase_token: purchaseToken,
      p_user_id: user.id,
    });

    if (error) {
      console.error("deliver_iap_purchase error", error);
      return jsonResponse({
        success: false,
        message: error.message ?? "Credit failed",
      }, 500);
    }

    const result = (data ?? {}) as Record<string, unknown>;
    if (result.success === true && result.duplicate !== true) {
      try {
        await acknowledgePlayPurchase({
          accessToken,
          packageName,
          productId,
          purchaseToken,
        });
      } catch (ackErr) {
        console.warn("acknowledge failed", ackErr);
      }
    }

    return jsonResponse(
      typeof result === "object" && result !== null
        ? { ...result }
        : { success: false, message: "Unexpected credit response" },
    );
  } catch (e) {
    console.error("verify-and-deliver-iap", e);
    return jsonResponse({
      success: false,
      message: e instanceof Error ? e.message : "Internal error",
    }, 500);
  }
});
