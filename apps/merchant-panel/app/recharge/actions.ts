"use server";

import { revalidatePath } from "next/cache";
import { supabaseAdmin } from "@/lib/supabase";
import { getMerchantActor } from "@/lib/merchant-session";
import {
  searchCoinSellers,
  searchAnyUsers,
  type SellerRow,
  type UserRow,
} from "@/lib/merchant-data";

export async function searchSellersAction(
  query: string,
): Promise<{ sellers: SellerRow[]; error?: string }> {
  const actor = await getMerchantActor();
  if (!actor) return { sellers: [], error: "Your session has expired" };
  return { sellers: await searchCoinSellers(actor.userId, query) };
}

/**
 * Send coin stock to a coin seller.
 *
 * The merchant id comes from the session only — never from the form — so a
 * crafted request cannot spend another merchant's wallet. The RPC still
 * re-checks the balance, the block flag, and that the target is a seller.
 */
export async function rechargeAction(
  sellerId: string,
  amount: number,
  note?: string,
): Promise<{ success: boolean; message: string; profit?: number; balance?: number }> {
  const actor = await getMerchantActor();
  if (!actor) return { success: false, message: "Your session has expired" };

  if (!Number.isFinite(amount) || amount <= 0) {
    return { success: false, message: "Enter an amount greater than zero" };
  }

  const { data, error } = await supabaseAdmin.rpc("merchant_recharge_reseller", {
    p_reseller_id: sellerId,
    p_amount: Math.trunc(amount),
    p_note: note?.trim() ? note.trim() : null,
    p_merchant_id: actor.userId,
  });

  if (error) {
    console.error("[merchant-panel] recharge", error.message);
    return { success: false, message: "Could not send the coins. Please try again." };
  }

  const res = data as {
    success?: boolean;
    message?: string;
    profit_coins?: number;
    balance?: number;
  } | null;

  if (!res?.success) {
    return { success: false, message: res?.message ?? "Transfer failed" };
  }

  revalidatePath("/");
  revalidatePath("/recharge");
  revalidatePath("/sellers");
  revalidatePath("/history");

  return {
    success: true,
    message: res.message ?? "Coins sent",
    profit: res.profit_coins,
    balance: res.balance,
  };
}

/** Search any account — for topping up a user ID or opening a coin seller. */
export async function searchUsersAction(
  query: string,
): Promise<{ users: UserRow[]; error?: string }> {
  const actor = await getMerchantActor();
  if (!actor) return { users: [], error: "Your session has expired" };
  return { users: await searchAnyUsers(actor.userId, query) };
}

/**
 * Send coins straight to a normal user's spendable balance.
 *
 * Unlike a coin-seller recharge this credits `coins`, not seller stock, so
 * the recipient can spend it immediately rather than resell it.
 */
export async function rechargeUserAction(
  userId: string,
  amount: number,
  note?: string,
): Promise<{ success: boolean; message: string; profit?: number; balance?: number }> {
  const actor = await getMerchantActor();
  if (!actor) return { success: false, message: "Your session has expired" };
  if (!Number.isFinite(amount) || amount <= 0) {
    return { success: false, message: "Enter an amount greater than zero" };
  }

  const { data, error } = await supabaseAdmin.rpc("merchant_recharge_user", {
    p_user_id: userId,
    p_amount: Math.trunc(amount),
    p_note: note?.trim() ? note.trim() : null,
    p_merchant_id: actor.userId,
  });

  if (error) {
    console.error("[merchant-panel] user recharge", error.message);
    return { success: false, message: "Could not send the coins. Please try again." };
  }
  const res = data as {
    success?: boolean; message?: string; profit_coins?: number; balance?: number;
  } | null;
  if (!res?.success) {
    return { success: false, message: res?.message ?? "Transfer failed" };
  }

  revalidatePath("/");
  revalidatePath("/recharge");
  revalidatePath("/history");
  return {
    success: true,
    message: res.message ?? "Coins sent",
    profit: res.profit_coins,
    balance: res.balance,
  };
}

/** Turn a normal account into a coin seller belonging to this merchant. */
export async function openResellerAction(
  userId: string,
): Promise<{ success: boolean; message: string }> {
  const actor = await getMerchantActor();
  if (!actor) return { success: false, message: "Your session has expired" };

  const { data, error } = await supabaseAdmin.rpc("merchant_open_reseller", {
    p_user_id: userId,
    p_merchant_id: actor.userId,
  });

  if (error) {
    console.error("[merchant-panel] open reseller", error.message);
    return { success: false, message: "Could not open the coin seller. Please try again." };
  }
  const res = data as { success?: boolean; message?: string } | null;
  if (!res?.success) {
    return { success: false, message: res?.message ?? "Could not open the coin seller" };
  }

  revalidatePath("/");
  revalidatePath("/recharge");
  revalidatePath("/sellers");
  return { success: true, message: res.message ?? "Coin seller opened" };
}
