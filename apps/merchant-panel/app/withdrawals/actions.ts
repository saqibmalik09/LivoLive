"use server";

import { revalidatePath } from "next/cache";
import { supabaseAdmin } from "@/lib/supabase";
import { getMerchantActor } from "@/lib/merchant-session";

/**
 * Request a payout. The RPC authorises on `auth.uid()`, which is absent on
 * a service-role connection, so the panel performs the same work directly:
 * re-read the balance under a lock-free check, hold the coins, write the
 * ledger row, and record the request.
 */
export async function requestWithdrawalAction(
  amount: number,
  method: string,
  details: string,
  note: string,
): Promise<{ success: boolean; message: string }> {
  const actor = await getMerchantActor();
  if (!actor) return { success: false, message: "Your session has expired" };

  const amt = Math.trunc(amount);
  if (!Number.isFinite(amt) || amt <= 0) {
    return { success: false, message: "Enter an amount greater than zero" };
  }

  const { data: u } = await supabaseAdmin
    .from("users")
    .select("merchant_coins, is_merchant, is_merchant_blocked")
    .eq("id", actor.userId)
    .maybeSingle();

  if (!u || u.is_merchant !== true) {
    return { success: false, message: "You are not an active merchant" };
  }
  if (u.is_merchant_blocked === true) {
    return { success: false, message: "Your account is blocked. Contact the admin." };
  }

  const balance = Number(u.merchant_coins ?? 0);
  if (balance < amt) {
    return {
      success: false,
      message: `Insufficient balance. You hold ${balance.toLocaleString()} coins.`,
    };
  }

  const { data: prof } = await supabaseAdmin
    .from("merchant_profiles")
    .select("coins_per_usd")
    .eq("user_id", actor.userId)
    .maybeSingle();
  const rate = Number(prof?.coins_per_usd ?? 0);

  // Hold the coins first; if any later step fails we put them back.
  const { data: afterRows, error: debitErr } = await supabaseAdmin
    .from("users")
    .update({ merchant_coins: balance - amt, updated_at: new Date().toISOString() })
    .eq("id", actor.userId)
    .eq("merchant_coins", balance) // optimistic guard against a concurrent change
    .select("merchant_coins");

  if (debitErr || !afterRows || afterRows.length === 0) {
    return {
      success: false,
      message: "Your balance changed just now — please check it and try again.",
    };
  }
  const after = Number(afterRows[0].merchant_coins ?? 0);

  const { data: wd, error: wdErr } = await supabaseAdmin
    .from("merchant_withdrawals")
    .insert({
      merchant_user_id: actor.userId,
      amount_coins: amt,
      amount_usd: rate > 0 ? Number((amt / rate).toFixed(2)) : null,
      method: method.trim() || null,
      account_details: details.trim() || null,
      note: note.trim() || null,
    })
    .select("id")
    .maybeSingle();

  if (wdErr || !wd) {
    await supabaseAdmin
      .from("users")
      .update({ merchant_coins: balance, updated_at: new Date().toISOString() })
      .eq("id", actor.userId);
    console.error("[merchant-panel] withdrawal insert", wdErr?.message);
    return { success: false, message: "Could not submit the request. Please try again." };
  }

  await supabaseAdmin.from("merchant_ledger").insert({
    merchant_user_id: actor.userId,
    entry_type: "withdrawal_hold",
    amount: amt,
    direction: -1,
    balance_after: after,
    performed_by: actor.userId,
    performed_by_role: "merchant",
    note: "Withdrawal requested",
  });

  revalidatePath("/");
  revalidatePath("/withdrawals");
  revalidatePath("/history");

  return {
    success: true,
    message: "Payout requested. The coins are held until the admin decides.",
  };
}
