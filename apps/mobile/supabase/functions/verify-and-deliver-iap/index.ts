import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.11.1/index.ts";

/** Shape of a real Google Play order id. Both lengths occur in production:
 *  GPA.3355-5202-6905-37952 and GPA.4283-1482-8377-7694-94381. */
const GPA_ORDER_RE = /^GPA\.\d{4}(?:-\d{4,6}){3,4}$/;

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

/** Carries Google's HTTP status so the caller can tell "bad purchase" from
 *  "our Play Console authorization is broken". */
class PlayVerifyError extends Error {
  status: number;
  reason: string | null;
  constructor(message: string, status: number, reason: string | null) {
    super(message);
    this.name = "PlayVerifyError";
    this.status = status;
    this.reason = reason;
  }
}

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
    throw new PlayVerifyError(
      typeof data?.error?.message === "string"
        ? data.error.message
        : "Purchase could not be verified with Google Play",
      res.status,
      typeof data?.error?.errors?.[0]?.reason === "string"
        ? data.error.errors[0].reason
        : null,
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

    const admin = createClient(supabaseUrl, serviceKey);

    const recordFailure = async (
      stage: string,
      httpStatus: number | null,
      reason: string | null,
      message: string,
    ) => {
      try {
        await admin.rpc("record_iap_verification_failure", {
          p_user_id: user.id,
          p_product_id: productId,
          p_purchase_id: purchaseId || null,
          p_purchase_token: purchaseToken,
          p_stage: stage,
          p_http_status: httpStatus,
          p_error_reason: reason,
          p_error_message: message,
        });
      } catch (recErr) {
        // Never let bookkeeping sink a purchase.
        console.error("record_iap_verification_failure failed", recErr);
      }
    };

    const sa = loadServiceAccount();
    const accessToken = await getGoogleAccessToken(sa);

    let play: PlayProductPurchase;
    try {
      play = await verifyPlayProductPurchase({
        accessToken,
        packageName,
        productId,
        purchaseToken,
      });
    } catch (verifyErr) {
      const status = verifyErr instanceof PlayVerifyError ? verifyErr.status : null;
      const reason = verifyErr instanceof PlayVerifyError ? verifyErr.reason : null;
      const message = verifyErr instanceof Error
        ? verifyErr.message
        : "Purchase could not be verified with Google Play";

      // 401/403 means OUR service account lost Play Console authorization — it says
      // nothing about the purchase. The app acknowledges purchases on-device
      // (completePurchase), so the customer has already been charged and Google will
      // not auto-refund. Withholding coins here would just keep their money, so
      // credit them and flag the row to be reconciled against Play Console Order
      // management once API access is restored.
      const outage = status === 401 || status === 403;
      await recordFailure(
        outage ? "play_verify_permission" : "play_verify",
        status,
        reason,
        message,
      );

      if (!outage) {
        return jsonResponse({ success: false, message }, 400);
      }

      // Without Google we cannot authenticate the purchase, so demand at least a
      // well-formed Google order id. deliver_iap_purchase still enforces a unique
      // purchase_id, a unique token, a known product and the per-hour cap.
      if (!GPA_ORDER_RE.test(purchaseId)) {
        console.warn("outage credit refused: bad order id", {
          purchaseId,
          user: user.id,
        });
        return jsonResponse({
          success: false,
          message: "Purchase could not be verified. Please contact support.",
        }, 400);
      }

      const { data: oData, error: oErr } = await admin.rpc("deliver_iap_purchase", {
        p_product_id: productId,
        p_purchase_id: purchaseId,
        p_purchase_token: purchaseToken,
        p_user_id: user.id,
      });

      if (oErr) {
        console.error("outage credit failed", oErr);
        return jsonResponse({
          success: false,
          message: oErr.message ?? "Credit failed",
        }, 500);
      }

      const oResult = (oData ?? {}) as Record<string, unknown>;
      if (oResult.success === true) {
        try {
          await admin.rpc("resolve_iap_verification", {
            p_purchase_token: purchaseToken,
            p_resolution: "credited_unverified",
          });
        } catch (resErr) {
          console.error("resolve_iap_verification failed", resErr);
        }
        console.warn("credited without Play verification", {
          user: user.id,
          purchaseId,
          productId,
        });
      }
      return jsonResponse({ ...oResult });
    }

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
