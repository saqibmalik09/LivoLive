"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { auditUserLabel, logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
function revalidateUserPaths(userId: string, staffId?: string | null) {
  revalidatePath(`/users/${userId}`);
  revalidatePath("/users");
  revalidatePath("/staff");
  revalidatePath("/agencies");
  if (staffId) revalidatePath(`/staff/${staffId}`);
}
async function assertNoActiveStaff(userId: string) {
  const { data } = await supabaseAdmin
    .from("business_staff")
    .select("id, role")
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (data) {
    throw new Error(`User already has an active staff role (${data.role})`);
  }
}
async function nextStaffCode(): Promise<string> {
  const { data, error } = await supabaseAdmin.rpc("generate_staff_code");
  if (!error && data) return String(data);
  return String(Math.floor(100000 + Math.random() * 900000));
}
function nextAgencyCode(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}
export async function updateUserCurrency(
  userId: string,
  type: "coins" | "diamonds" | "reseller_coins" | "cash_balance",
  amount: number,
) {
  try {
    const { data, error } = await supabaseAdmin
      .from("users")
      .update({ [type]: amount })
      .eq("id", userId)
      .select();
    if (error) throw error;
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.currency_update",
      targetType: "user",
      targetId: userId,
      summary: `Set ${type} to ${amount} for ${who}`,
      metadata: { type, amount },
    });
    revalidatePath(`/users/${userId}`);
    revalidatePath("/users");
    return { success: true, data };
  } catch (error: any) {
    console.error("Error updating currency:", error);
    return { success: false, error: error.message };
  }
}
export async function updateUserCountry(userId: string, countryCode: string | null) {
  try {
    let value: string | null = null;
    if (countryCode != null && String(countryCode).trim() !== "") {
      const upper = String(countryCode).trim().toUpperCase().slice(0, 2);
      if (!/^[A-Z]{2}$/.test(upper)) {
        throw new Error("Country must be a 2-letter ISO code (e.g. PK)");
      }
      value = upper;
    }
    const { data, error } = await supabaseAdmin
      .from("users")
      .update({ country_code: value, updated_at: new Date().toISOString() })
      .eq("id", userId)
      .select("id, country_code")
      .single();
    if (error) throw error;
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.country_update",
      targetType: "user",
      targetId: userId,
      summary: `Set country to ${value || "none"} for ${who}`,
      metadata: { country_code: value },
    });
    revalidatePath(`/users/${userId}`);
    revalidatePath("/users");
    return { success: true, data };
  } catch (error: any) {
    console.error("Error updating country:", error);
    return { success: false, error: error.message };
  }
}
export async function setUserSpecialId(
  userId: string,
  opts: {
    level?: number | null;
    shortId?: number | null;
  },
) {
  try {
    const p_level = opts.level === undefined || opts.level === null ? null : Number(opts.level);
    const p_short_id =
      opts.shortId === undefined || opts.shortId === null ? null : Number(opts.shortId);
    const { data, error } = await supabaseAdmin.rpc("admin_set_user_special_id", {
      p_user_id: userId,
      p_level,
      p_short_id,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || "Failed");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.special_id",
      targetType: "user",
      targetId: userId,
      summary: `Set special ID (level ${p_level ?? "unchanged"}, short_id ${p_short_id ?? "unchanged"}) for ${who}`,
      metadata: { level: p_level, short_id: p_short_id },
    });
    revalidatePath(`/users/${userId}`);
    revalidatePath("/users");
    return { success: true, data };
  } catch (error: any) {
    console.error("Error setting special ID:", error);
    return { success: false, error: error.message };
  }
}
export async function toggleUserBan(
  userId: string,
  currentStatus: boolean,
  banReason?: string | null,
) {
  try {
    const nextBanned = !currentStatus;
    const note = nextBanned ? banReason?.trim() || null : null;
    const { data, error } = await supabaseAdmin
      .from("users")
      .update(
        nextBanned
          ? {
              is_banned: true,
              ban_reason: note,
              banned_at: new Date().toISOString(),
            }
          : {
              is_banned: false,
              ban_reason: null,
              banned_at: null,
            },
      )
      .eq("id", userId)
      .select("id, is_banned, ban_reason, banned_at");
    if (error) throw error;
    if (!data?.length) {
      throw new Error("User not found or ban update blocked");
    }
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: nextBanned ? "user.ban" : "user.unban",
      targetType: "user",
      targetId: userId,
      summary: `${nextBanned ? "Blocked" : "Unblocked"} ${who}`,
      metadata: {
        is_banned: nextBanned,
        ban_reason: note,
      },
    });
    revalidatePath(`/users/${userId}`);
    revalidatePath("/users");
    return { success: true, data: data[0] };
  } catch (error: any) {
    console.error("Error toggling ban:", error);
    return { success: false, error: error.message };
  }
}
export async function banUserDevice(userId: string, deviceId: string, reason?: string | null) {
  try {
    const note = reason?.trim() || null;
    const now = new Date().toISOString();
    const { data: userRow, error: userErr } = await supabaseAdmin
      .from("users")
      .select("last_device_id, last_android_id, fcm_token")
      .eq("id", userId)
      .maybeSingle();
    if (userErr) throw userErr;
    const installId = (userRow?.last_device_id as string | null)?.trim() || deviceId?.trim() || "";
    const androidId = (userRow?.last_android_id as string | null)?.trim() || "";
    const fcmToken = (userRow?.fcm_token as string | null)?.trim() || "";
    const signals: Array<{
      signal_type: string;
      signal_value: string;
    }> = [];
    if (installId.length >= 8) {
      signals.push({ signal_type: "install_id", signal_value: installId });
    }
    if (androidId.length >= 8) {
      signals.push({ signal_type: "android_id", signal_value: androidId });
    }
    if (fcmToken.length >= 20) {
      signals.push({ signal_type: "fcm_token", signal_value: fcmToken });
    }
    if (signals.length === 0) {
      throw new Error(
        "No device signals on this user yet (install id / ANDROID_ID / FCM). Ask them to open the app once.",
      );
    }
    const { error: sigErr } = await supabaseAdmin.from("banned_device_signals").upsert(
      signals.map((s) => ({
        ...s,
        reason: note,
        banned_at: now,
        last_user_id: userId,
        is_active: true,
      })),
      { onConflict: "signal_type,signal_value" },
    );
    if (sigErr) throw sigErr;
    if (installId.length >= 8) {
      const { error } = await supabaseAdmin.from("banned_devices").upsert(
        {
          device_id: installId,
          reason: note,
          banned_at: now,
          last_user_id: userId,
          is_active: true,
        },
        { onConflict: "device_id" },
      );
      if (error) throw error;
    }
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.device_ban",
      targetType: "user",
      targetId: userId,
      summary: `Banned device signals for ${who}`,
      metadata: {
        signals: signals.map((s) => s.signal_type),
        reason: note,
      },
    });
    revalidatePath(`/users/${userId}`);
    revalidatePath("/users");
    return { success: true as const };
  } catch (error: any) {
    console.error("Error banning device:", error);
    return { success: false as const, error: error.message };
  }
}
export async function unbanUserDevice(userId: string, deviceId: string) {
  try {
    const { data: userRow, error: userErr } = await supabaseAdmin
      .from("users")
      .select("last_device_id, last_android_id, fcm_token")
      .eq("id", userId)
      .maybeSingle();
    if (userErr) throw userErr;
    const installId = (userRow?.last_device_id as string | null)?.trim() || deviceId?.trim() || "";
    const androidId = (userRow?.last_android_id as string | null)?.trim() || "";
    const fcmToken = (userRow?.fcm_token as string | null)?.trim() || "";
    const { error: byUserErr } = await supabaseAdmin
      .from("banned_device_signals")
      .update({ is_active: false })
      .eq("last_user_id", userId)
      .eq("is_active", true);
    if (byUserErr) throw byUserErr;
    const pairs: Array<{
      signal_type: string;
      signal_value: string;
    }> = [];
    if (installId.length >= 8) {
      pairs.push({ signal_type: "install_id", signal_value: installId });
    }
    if (androidId.length >= 8) {
      pairs.push({ signal_type: "android_id", signal_value: androidId });
    }
    if (fcmToken.length >= 20) {
      pairs.push({ signal_type: "fcm_token", signal_value: fcmToken });
    }
    for (const p of pairs) {
      const { error } = await supabaseAdmin
        .from("banned_device_signals")
        .update({ is_active: false })
        .eq("signal_type", p.signal_type)
        .eq("signal_value", p.signal_value);
      if (error) throw error;
    }
    if (installId) {
      const { error } = await supabaseAdmin
        .from("banned_devices")
        .update({ is_active: false })
        .eq("device_id", installId);
      if (error) throw error;
    }
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.device_unban",
      targetType: "user",
      targetId: userId,
      summary: `Unbanned device signals for ${who}`,
      metadata: {
        signals: pairs.map((s) => s.signal_type),
        device_id: installId || null,
      },
    });
    revalidatePath(`/users/${userId}`);
    revalidatePath("/users");
    return { success: true as const };
  } catch (error: any) {
    console.error("Error unbanning device:", error);
    return { success: false as const, error: error.message };
  }
}
export async function resetUserPassword(userId: string, newPassword: string) {
  try {
    const password = String(newPassword ?? "").trim();
    if (!userId) throw new Error("User id is required");
    if (password.length < 6) {
      throw new Error("Password must be at least 6 characters");
    }
    if (password.length > 72) {
      throw new Error("Password must be at most 72 characters");
    }
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.updateUserById(
      userId,
      { password },
    );
    if (authError) throw authError;
    if (!authData?.user) throw new Error("Auth user not found");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.password_reset",
      targetType: "user",
      targetId: userId,
      summary: `Reset login password for ${who}`,
      metadata: {
        has_email: !!authData.user.email,
        providers: (authData.user.identities ?? []).map((i) => i.provider),
      },
    });
    revalidatePath(`/users/${userId}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error resetting user password:", error);
    return { success: false, error: error.message ?? "Failed to reset password" };
  }
}
export async function toggleReseller(userId: string, currentStatus: boolean) {
  try {
    const next = !currentStatus;
    const { data, error } = await supabaseAdmin
      .from("users")
      .update({ is_reseller: next })
      .eq("id", userId)
      .select();
    if (error) throw error;
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: next ? "user.reseller_enable" : "user.reseller_disable",
      targetType: "user",
      targetId: userId,
      summary: `${next ? "Enabled" : "Disabled"} reseller for ${who}`,
      metadata: { is_reseller: next },
    });
    revalidatePath(`/users/${userId}`);
    revalidatePath("/users");
    return { success: true, data };
  } catch (error: any) {
    console.error("Error toggling reseller:", error);
    return { success: false, error: error.message };
  }
}
export async function promoteToSuperBd(userId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc("create_business_staff", {
      p_target_user_id: userId,
      p_role: "super_bd",
      p_parent_staff_id: null,
      p_created_by_user_id: null,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || "Failed to create Super BD");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.promote_super_bd",
      targetType: "user",
      targetId: userId,
      summary: `Made ${who} Super Admin`,
      metadata: { role: "super_bd", staff: data },
    });
    revalidateUserPaths(userId);
    return { success: true, data };
  } catch (error: any) {
    console.error("Error creating Super BD:", error);
    return { success: false, error: error.message };
  }
}
export async function removeSuperBd(staffId: string, userId: string) {
  return deactivateStaffRole(staffId, userId);
}
export async function deactivateStaffRole(staffId: string, userId: string) {
  try {
    const { data: staffRow } = await supabaseAdmin
      .from("business_staff")
      .select("id, role")
      .eq("id", staffId)
      .maybeSingle();
    const { error } = await supabaseAdmin
      .from("business_staff")
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq("id", staffId);
    if (error) throw error;
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "staff.deactivate",
      targetType: "staff",
      targetId: staffId,
      summary: `Deactivated ${staffRow?.role || "staff"} role for ${who}`,
      metadata: { user_id: userId, role: staffRow?.role },
    });
    revalidateUserPaths(userId, staffId);
    return { success: true };
  } catch (error: any) {
    console.error("Error deactivating staff role:", error);
    return { success: false, error: error.message };
  }
}
export async function promoteToBdAdmin(userId: string, parentSuperBdStaffId: string) {
  try {
    if (!parentSuperBdStaffId) throw new Error("Select a Super Admin parent");
    const { data: parent, error: parentErr } = await supabaseAdmin
      .from("business_staff")
      .select("id, role, is_active")
      .eq("id", parentSuperBdStaffId)
      .maybeSingle();
    if (parentErr) throw parentErr;
    if (!parent?.is_active || parent.role !== "super_bd") {
      throw new Error("Parent must be an active Super Admin");
    }
    await assertNoActiveStaff(userId);
    const { data, error } = await supabaseAdmin.rpc("create_business_staff", {
      p_target_user_id: userId,
      p_role: "county_admin",
      p_parent_staff_id: parentSuperBdStaffId,
      p_created_by_user_id: null,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || "Failed to create County Admin");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.promote_county_admin",
      targetType: "user",
      targetId: userId,
      summary: `Made ${who} County Admin`,
      metadata: { role: "county_admin", parent_staff_id: parentSuperBdStaffId, staff: data },
    });
    revalidateUserPaths(userId);
    return { success: true, data };
  } catch (error: any) {
    console.error("Error creating County Admin:", error);
    return { success: false, error: error.message };
  }
}
export async function promoteToBd(userId: string, parentBdAdminStaffId: string) {
  try {
    if (!parentBdAdminStaffId) throw new Error("Select a County Admin (or Super Admin) parent");
    const { data: parent, error: parentErr } = await supabaseAdmin
      .from("business_staff")
      .select("id, role, is_active")
      .eq("id", parentBdAdminStaffId)
      .maybeSingle();
    if (parentErr) throw parentErr;
    const parentRole = parent?.role === "bd_admin" ? "county_admin" : parent?.role;
    if (!parent?.is_active || (parentRole !== "county_admin" && parentRole !== "super_bd")) {
      throw new Error("Parent must be an active County Admin or Super Admin");
    }
    await assertNoActiveStaff(userId);
    const { data, error } = await supabaseAdmin.rpc("create_business_staff", {
      p_target_user_id: userId,
      p_role: "bd",
      p_parent_staff_id: parentBdAdminStaffId,
      p_created_by_user_id: null,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || "Failed to create BD");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.promote_bd",
      targetType: "user",
      targetId: userId,
      summary: `Made ${who} BD`,
      metadata: { role: "bd", parent_staff_id: parentBdAdminStaffId, staff: data },
    });
    revalidateUserPaths(userId);
    return { success: true, data };
  } catch (error: any) {
    console.error("Error creating BD:", error);
    return { success: false, error: error.message };
  }
}
export async function createAgencyForOwner(
  userId: string,
  agencyName: string,
  sponsorStaffId?: string | null,
) {
  try {
    const name = agencyName?.trim();
    if (!name) throw new Error("Agency name is required");
    const { data: existing } = await supabaseAdmin
      .from("agencies")
      .select("id, name")
      .eq("owner_id", userId)
      .maybeSingle();
    if (existing) {
      throw new Error(`User already owns agency: ${existing.name}`);
    }
    if (sponsorStaffId) {
      const { data: sponsor } = await supabaseAdmin
        .from("business_staff")
        .select("id, is_active")
        .eq("id", sponsorStaffId)
        .maybeSingle();
      if (!sponsor?.is_active) throw new Error("Sponsor staff is not active");
    }
    let agencyCode = nextAgencyCode();
    for (let i = 0; i < 5; i++) {
      const { error } = await supabaseAdmin.from("agencies").insert({
        owner_id: userId,
        name,
        agency_code: agencyCode,
        is_active: true,
        sponsor_staff_id: sponsorStaffId || null,
        approved_by_staff_id: null,
      });
      if (!error) {
        const who = await auditUserLabel(userId);
        await logAdminAction({
          action: "agency.create",
          targetType: "user",
          targetId: userId,
          summary: `Created agency "${name}" (${agencyCode}) for ${who}`,
          metadata: {
            agency_name: name,
            agency_code: agencyCode,
            sponsor_staff_id: sponsorStaffId || null,
          },
        });
        revalidateUserPaths(userId);
        return { success: true };
      }
      if (error.message?.toLowerCase().includes("agency_code") || error.code === "23505") {
        agencyCode = nextAgencyCode();
        continue;
      }
      throw error;
    }
    throw new Error("Failed to generate unique agency code");
  } catch (error: any) {
    console.error("Error creating agency for owner:", error);
    return { success: false, error: error.message };
  }
}
export async function assignHostToAgency(userId: string, agencyId: string) {
  try {
    if (!agencyId) throw new Error("Select an agency");
    const { data: agency, error: agencyErr } = await supabaseAdmin
      .from("agencies")
      .select("id, name, is_active")
      .eq("id", agencyId)
      .maybeSingle();
    if (agencyErr) throw agencyErr;
    if (!agency) throw new Error("Agency not found");
    if (agency.is_active === false) throw new Error("Agency is inactive");
    const { data: existing } = await supabaseAdmin
      .from("agency_members")
      .select("id, agency_id")
      .eq("user_id", userId)
      .maybeSingle();
    if (existing?.agency_id === agencyId) {
      throw new Error("User is already a host in this agency");
    }
    if (existing) {
      return transferHostToAgency(userId, agencyId, existing.agency_id);
    }
    const { error } = await supabaseAdmin.from("agency_members").insert({
      agency_id: agencyId,
      user_id: userId,
      role: "host",
    });
    if (error) throw error;
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "agency.assign_host",
      targetType: "agency",
      targetId: agencyId,
      summary: `Assigned ${who} to agency ${agency.name}`,
      metadata: { user_id: userId, agency_name: agency.name },
    });
    revalidateUserPaths(userId);
    revalidatePath(`/agencies/${agencyId}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error assigning host:", error);
    return { success: false, error: error.message };
  }
}
export async function removeHostFromAgency(userId: string, agencyId: string) {
  try {
    if (!userId) throw new Error("User required");
    if (!agencyId) throw new Error("Agency required");
    const { error: eventErr } = await supabaseAdmin.from("agency_member_events").insert({
      agency_id: agencyId,
      user_id: userId,
      event_type: "removed",
      actor_id: null,
    });
    if (eventErr) console.warn("[removeHostFromAgency] event", eventErr.message);
    const { error } = await supabaseAdmin
      .from("agency_members")
      .delete()
      .eq("user_id", userId)
      .eq("agency_id", agencyId);
    if (error) throw error;
    await supabaseAdmin
      .from("agency_applications")
      .update({ status: "rejected" })
      .eq("user_id", userId)
      .eq("agency_id", agencyId)
      .eq("status", "pending");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "agency.remove_host",
      targetType: "agency",
      targetId: agencyId,
      summary: `Removed ${who} from agency (account kept; free to join another)`,
      metadata: { user_id: userId, account_deleted: false },
    });
    revalidateUserPaths(userId);
    revalidatePath(`/agencies/${agencyId}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error removing host:", error);
    return { success: false, error: error.message };
  }
}
export async function transferHostToAgency(
  userId: string,
  toAgencyId: string,
  fromAgencyId?: string | null,
) {
  try {
    if (!userId) throw new Error("User required");
    if (!toAgencyId) throw new Error("Select destination agency");
    const { data: toAgency, error: toErr } = await supabaseAdmin
      .from("agencies")
      .select("id, name, is_active")
      .eq("id", toAgencyId)
      .maybeSingle();
    if (toErr) throw toErr;
    if (!toAgency) throw new Error("Destination agency not found");
    if (toAgency.is_active === false) throw new Error("Destination agency is inactive");
    const { data: membership, error: memErr } = await supabaseAdmin
      .from("agency_members")
      .select("id, agency_id, role")
      .eq("user_id", userId)
      .maybeSingle();
    if (memErr) throw memErr;
    if (membership?.agency_id === toAgencyId) {
      throw new Error("User is already in this agency");
    }
    if (fromAgencyId && membership && membership.agency_id !== fromAgencyId) {
      throw new Error("User is not in the selected source agency");
    }
    let fromAgencyName: string | null = null;
    const sourceId = membership?.agency_id ?? fromAgencyId ?? null;
    if (sourceId) {
      const { data: fromAgency } = await supabaseAdmin
        .from("agencies")
        .select("name")
        .eq("id", sourceId)
        .maybeSingle();
      fromAgencyName = fromAgency?.name ? String(fromAgency.name) : null;
    }
    if (membership) {
      const { error } = await supabaseAdmin
        .from("agency_members")
        .update({ agency_id: toAgencyId })
        .eq("id", membership.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("agency_members").insert({
        agency_id: toAgencyId,
        user_id: userId,
        role: "host",
      });
      if (error) throw error;
    }
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "agency.transfer_host",
      targetType: "agency",
      targetId: toAgencyId,
      summary: fromAgencyName
        ? `Transferred ${who} from ${fromAgencyName} to ${toAgency.name}`
        : `Transferred ${who} to ${toAgency.name}`,
      metadata: {
        user_id: userId,
        from_agency_id: sourceId,
        to_agency_id: toAgencyId,
        from_agency_name: fromAgencyName,
        to_agency_name: toAgency.name,
      },
    });
    revalidateUserPaths(userId);
    if (sourceId) revalidatePath(`/agencies/${sourceId}`);
    revalidatePath(`/agencies/${toAgencyId}`);
    revalidatePath("/agencies");
    return { success: true };
  } catch (error: any) {
    console.error("Error transferring host:", error);
    return { success: false, error: error.message };
  }
}
export async function transferAgencyToBd(agencyId: string, newSponsorStaffId: string | null) {
  try {
    if (!agencyId) throw new Error("Agency required");
    const { data: agency, error: agencyErr } = await supabaseAdmin
      .from("agencies")
      .select("id, name, sponsor_staff_id")
      .eq("id", agencyId)
      .maybeSingle();
    if (agencyErr) throw agencyErr;
    if (!agency) throw new Error("Agency not found");
    let newSponsorLabel: string | null = null;
    if (newSponsorStaffId) {
      const { data: sponsor, error: sponsorErr } = await supabaseAdmin
        .from("business_staff")
        .select("id, staff_code, role, is_active, user:user_id(username)")
        .eq("id", newSponsorStaffId)
        .maybeSingle();
      if (sponsorErr) throw sponsorErr;
      if (!sponsor) throw new Error("BD staff not found");
      if (!sponsor.is_active) throw new Error("BD staff is not active");
      if (sponsor.role !== "bd") {
        throw new Error("Sponsor must be a BD");
      }
      const u = Array.isArray(sponsor.user) ? sponsor.user[0] : sponsor.user;
      newSponsorLabel = `${sponsor.staff_code}${u?.username ? ` (@${u.username})` : ""}`;
    }
    if ((agency.sponsor_staff_id || null) === (newSponsorStaffId || null)) {
      throw new Error("Agency is already under this BD");
    }
    const { error } = await supabaseAdmin
      .from("agencies")
      .update({ sponsor_staff_id: newSponsorStaffId || null })
      .eq("id", agencyId);
    if (error) throw error;
    await logAdminAction({
      action: "agency.change_sponsor",
      targetType: "agency",
      targetId: agencyId,
      summary: newSponsorLabel
        ? `Moved agency ${agency.name} under BD ${newSponsorLabel}`
        : `Removed BD sponsor from agency ${agency.name}`,
      metadata: {
        agency_name: agency.name,
        from_sponsor_staff_id: agency.sponsor_staff_id,
        to_sponsor_staff_id: newSponsorStaffId,
      },
    });
    revalidatePath(`/agencies/${agencyId}`);
    revalidatePath("/agencies");
    if (agency.sponsor_staff_id) revalidatePath(`/staff/${agency.sponsor_staff_id}`);
    if (newSponsorStaffId) revalidatePath(`/staff/${newSponsorStaffId}`);
    return { success: true };
  } catch (error: any) {
    console.error("Error transferring agency to BD:", error);
    return { success: false, error: error.message };
  }
}
function revalidateProfilePaths(userId: string) {
  revalidatePath(`/users/${userId}`);
  revalidatePath("/users");
}
export async function updateUserProfile(
  userId: string,
  data: {
    username?: string;
    bio?: string | null;
    avatar_url?: string | null;
    banner_url?: string | null;
  },
) {
  try {
    const payload: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };
    if (data.username !== undefined) {
      const name = data.username.trim();
      if (!name) throw new Error("Username is required");
      payload.username = name;
    }
    if (data.bio !== undefined) payload.bio = data.bio?.trim() || null;
    if (data.avatar_url !== undefined) {
      payload.avatar_url = data.avatar_url?.trim() || null;
    }
    if (data.banner_url !== undefined) {
      payload.banner_url = data.banner_url?.trim() || null;
    }
    const { error } = await supabaseAdmin.from("users").update(payload).eq("id", userId);
    if (error) throw error;
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error updating profile:", error);
    return { success: false, error: error.message };
  }
}
export async function uploadUserMedia(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const kind = String(formData.get("kind") || "avatar");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName = fileEntry instanceof File && fileEntry.name ? fileEntry.name : "media.png";
    const fileType = fileEntry instanceof File ? fileEntry.type : "";
    const { resolveRankingAssetContentType, resolveRankingAssetExtension } =
      await import("@/lib/ranking-asset-media");
    const ext = resolveRankingAssetExtension(originalName, fileType);
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const safeBase = originalName
      .replace(/\s+/g, "_")
      .replace(/\.[^.]+$/, "")
      .slice(0, 40);
    const folder =
      kind === "banner" || kind === "room_banner" || kind === "room_bg"
        ? "users/media"
        : "users/avatars";
    const fileName = `${folder}/${kind}-${Date.now()}-${safeBase}.${ext}`;
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType: contentType,
    });
    return { success: true as const, url: publicUrl };
  } catch (error: any) {
    console.error("Error uploading user media:", error);
    return { success: false as const, error: error.message as string };
  }
}
export async function updateUserLevels(
  userId: string,
  data: {
    user_level?: number;
    wealth_level?: number;
    wealth_value?: number;
    charm_level?: number;
    charm_value?: number;
    vip_level?: number;
  },
) {
  try {
    const payload: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };
    const intFields = [
      "user_level",
      "wealth_level",
      "wealth_value",
      "charm_level",
      "charm_value",
      "vip_level",
    ] as const;
    for (const key of intFields) {
      if (data[key] !== undefined) {
        const n = Number(data[key]);
        if (!Number.isFinite(n) || n < 0) throw new Error(`Invalid ${key}`);
        payload[key] = Math.floor(n);
      }
    }
    const { error } = await supabaseAdmin.from("users").update(payload).eq("id", userId);
    if (error) throw error;
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error updating levels:", error);
    return { success: false, error: error.message };
  }
}
async function getHostRoomId(userId: string): Promise<string | null> {
  const { data } = await supabaseAdmin
    .from("rooms")
    .select("id")
    .eq("host_id", userId)
    .maybeSingle();
  return data?.id ?? null;
}
export async function updateRoomLevel(
  userId: string,
  data: {
    current_level?: number;
    total_exp?: number;
  },
) {
  try {
    const roomId = await getHostRoomId(userId);
    if (!roomId) throw new Error("User has no host room");
    const payload: Record<string, unknown> = {};
    if (data.current_level !== undefined) {
      const n = Number(data.current_level);
      if (!Number.isFinite(n) || n < 0) throw new Error("Invalid room level");
      payload.current_level = Math.floor(n);
    }
    if (data.total_exp !== undefined) {
      const n = Number(data.total_exp);
      if (!Number.isFinite(n) || n < 0) throw new Error("Invalid room exp");
      payload.total_exp = Math.floor(n);
    }
    if (Object.keys(payload).length === 0) {
      throw new Error("Nothing to update");
    }
    const { data: existing } = await supabaseAdmin
      .from("room_stats")
      .select("room_id")
      .eq("room_id", roomId)
      .maybeSingle();
    if (existing) {
      const { error } = await supabaseAdmin
        .from("room_stats")
        .update(payload)
        .eq("room_id", roomId);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("room_stats").insert({
        room_id: roomId,
        current_level: Number(payload.current_level ?? 1),
        total_exp: Number(payload.total_exp ?? 0),
      });
      if (error) throw error;
    }
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error updating room level:", error);
    return { success: false, error: error.message };
  }
}
async function unequipSameCategory(userId: string, categoryName: string) {
  const { data: rows } = await supabaseAdmin
    .from("user_inventory")
    .select("id, shop_items(shop_categories(name))")
    .eq("user_id", userId);
  const ids = (rows ?? [])
    .filter((row: any) => {
      const item = Array.isArray(row.shop_items) ? row.shop_items[0] : row.shop_items;
      const catRaw = item?.shop_categories;
      const cat = Array.isArray(catRaw)
        ? String(catRaw[0]?.name ?? "").toLowerCase()
        : String(catRaw?.name ?? "").toLowerCase();
      return cat === categoryName.toLowerCase();
    })
    .map((row: any) => row.id as string);
  if (ids.length > 0) {
    await supabaseAdmin.from("user_inventory").update({ is_equipped: false }).in("id", ids);
  }
}
async function equipInventoryRow(inventoryId: string, userId: string, categoryName: string) {
  const { error: rpcError } = await supabaseAdmin.rpc("equip_user_asset", {
    p_asset_id: inventoryId,
    p_user_id: userId,
    p_category_name: categoryName,
  });
  if (!rpcError) return;
  await unequipSameCategory(userId, categoryName);
  const { error } = await supabaseAdmin
    .from("user_inventory")
    .update({ is_equipped: true })
    .eq("id", inventoryId)
    .eq("user_id", userId);
  if (error) throw error;
}
export async function grantInventoryItem(
  userId: string,
  itemId: string,
  opts?: {
    equip?: boolean;
  },
) {
  try {
    if (!itemId) throw new Error("Select a shop item");
    const { data: item, error: itemErr } = await supabaseAdmin
      .from("shop_items")
      .select("id, name, shop_categories(name)")
      .eq("id", itemId)
      .maybeSingle();
    if (itemErr) throw itemErr;
    if (!item) throw new Error("Shop item not found");
    const { data: existing } = await supabaseAdmin
      .from("user_inventory")
      .select("id")
      .eq("user_id", userId)
      .eq("item_id", itemId)
      .maybeSingle();
    let inventoryId = existing?.id as string | undefined;
    if (!inventoryId) {
      const permanentExpiry = "9999-12-31T00:00:00.000Z";
      const baseRow = {
        user_id: userId,
        item_id: itemId,
        is_equipped: false,
        expires_at: permanentExpiry,
      };
      let inserted: {
        id: string;
      } | null = null;
      let error: {
        message?: string;
      } | null = null;
      ({ data: inserted, error } = await supabaseAdmin
        .from("user_inventory")
        .insert({ ...baseRow, source: "admin" })
        .select("id")
        .single());
      if (error && /source/i.test(error.message ?? "")) {
        ({ data: inserted, error } = await supabaseAdmin
          .from("user_inventory")
          .insert(baseRow)
          .select("id")
          .single());
      }
      if (error) throw error;
      inventoryId = inserted!.id;
    }
    if (opts?.equip && inventoryId) {
      const catRaw = item.shop_categories as
        | {
            name?: string;
          }
        | {
            name?: string;
          }[]
        | null;
      const catName = Array.isArray(catRaw)
        ? (catRaw[0]?.name ?? "Unknown")
        : (catRaw?.name ?? "Unknown");
      await equipInventoryRow(inventoryId, userId, catName);
    }
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error granting inventory item:", error);
    return { success: false, error: error.message };
  }
}
export async function equipInventoryItem(
  inventoryId: string,
  userId: string,
  categoryName: string,
) {
  try {
    if (!inventoryId || !categoryName) throw new Error("Missing inventory/category");
    await equipInventoryRow(inventoryId, userId, categoryName);
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error equipping item:", error);
    return { success: false, error: error.message };
  }
}
export async function unequipInventoryItem(inventoryId: string, userId: string) {
  try {
    const { error } = await supabaseAdmin
      .from("user_inventory")
      .update({ is_equipped: false })
      .eq("id", inventoryId)
      .eq("user_id", userId);
    if (error) throw error;
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error unequipping item:", error);
    return { success: false, error: error.message };
  }
}
export async function removeInventoryItem(inventoryId: string, userId: string) {
  try {
    const { error } = await supabaseAdmin
      .from("user_inventory")
      .delete()
      .eq("id", inventoryId)
      .eq("user_id", userId);
    if (error) throw error;
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error removing inventory item:", error);
    return { success: false, error: error.message };
  }
}
export async function updateUserRoom(
  userId: string,
  data: {
    image_url?: string | null;
    background_url?: string | null;
    decoration_id?: string | null;
    is_pinned?: boolean;
    pin_slot?: number;
  },
) {
  try {
    const roomId = await getHostRoomId(userId);
    if (!roomId) throw new Error("User has no host room");
    const payload: Record<string, unknown> = {};
    if (data.image_url !== undefined) {
      payload.image_url = data.image_url?.trim() || null;
    }
    if (data.background_url !== undefined) {
      payload.background_url = data.background_url?.trim() || null;
    }
    if (data.decoration_id !== undefined) {
      payload.decoration_id = data.decoration_id?.trim() || null;
    }
    if (data.pin_slot !== undefined) {
      const slot = Math.floor(Number(data.pin_slot));
      if (![0, 1, 2, 3].includes(slot)) {
        throw new Error("Pin slot must be 1, 2, 3, or 0");
      }
      if (slot === 0) {
        payload.is_pinned = false;
        payload.pin_order = 0;
      } else {
        await supabaseAdmin
          .from("rooms")
          .update({ is_pinned: false, pin_order: 0 })
          .eq("is_pinned", true)
          .eq("pin_order", slot)
          .neq("id", roomId);
        payload.is_pinned = true;
        payload.pin_order = slot;
      }
    } else if (data.is_pinned !== undefined) {
      if (!data.is_pinned) {
        payload.is_pinned = false;
        payload.pin_order = 0;
      } else {
        const { data: usedRows } = await supabaseAdmin
          .from("rooms")
          .select("pin_order")
          .eq("is_pinned", true)
          .gte("pin_order", 1)
          .lte("pin_order", 3);
        const used = new Set((usedRows ?? []).map((r: any) => Number(r.pin_order)));
        const free = [1, 2, 3].find((s) => !used.has(s));
        if (!free) throw new Error("All pin slots 1–3 are full");
        payload.is_pinned = true;
        payload.pin_order = free;
      }
    }
    if (Object.keys(payload).length === 0) {
      throw new Error("Nothing to update");
    }
    const { error } = await supabaseAdmin.from("rooms").update(payload).eq("id", roomId);
    if (error) throw error;
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error updating room:", error);
    return { success: false, error: error.message };
  }
}
export async function updateUserShortId(userId: string, shortId: number) {
  try {
    const id = Math.floor(Number(shortId));
    if (!Number.isFinite(id) || id <= 0) {
      throw new Error("UID must be a positive number");
    }
    const { data: taken } = await supabaseAdmin
      .from("users")
      .select("id")
      .eq("short_id", id)
      .neq("id", userId)
      .maybeSingle();
    if (taken) throw new Error(`UID ${id} is already used by another user`);
    const { error } = await supabaseAdmin
      .from("users")
      .update({ short_id: id, updated_at: new Date().toISOString() })
      .eq("id", userId);
    if (error) throw error;
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error updating short_id:", error);
    return { success: false, error: error.message };
  }
}
export async function setUserVipPlan(
  userId: string,
  planId: string,
  opts?: {
    replaceExpiry?: boolean;
  },
) {
  try {
    if (!planId) throw new Error("Select a VIP plan");
    const { data: plan, error: planErr } = await supabaseAdmin
      .from("vip_plans")
      .select("id, level, name, duration_days")
      .eq("id", planId)
      .maybeSingle();
    if (planErr) throw planErr;
    if (!plan) throw new Error("VIP plan not found");
    const duration = Math.max(1, Number(plan.duration_days) || 30);
    const level = Number(plan.level) || 0;
    if (level <= 0) throw new Error("Invalid VIP plan level");
    const { data: user, error: userErr } = await supabaseAdmin
      .from("users")
      .select("vip_until")
      .eq("id", userId)
      .single();
    if (userErr) throw userErr;
    const now = Date.now();
    const currentUntil = user?.vip_until ? new Date(user.vip_until).getTime() : 0;
    let newUntil: Date;
    if (!opts?.replaceExpiry && currentUntil > now) {
      newUntil = new Date(currentUntil + duration * 24 * 60 * 60 * 1000);
    } else {
      newUntil = new Date(now + duration * 24 * 60 * 60 * 1000);
    }
    const { error } = await supabaseAdmin
      .from("users")
      .update({
        vip_level: level,
        vip_until: newUntil.toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", userId);
    if (error) throw error;
    const { error: provisionErr } = await supabaseAdmin.rpc("provision_user_assets", {
      p_user_id: userId,
    });
    if (provisionErr) {
      console.warn("provision_user_assets warning:", provisionErr.message);
    }
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.vip_set",
      targetType: "user",
      targetId: userId,
      summary: `Set VIP ${plan.name || level} for ${who}`,
      metadata: {
        plan_id: planId,
        level,
        duration_days: duration,
        vip_until: newUntil.toISOString(),
      },
    });
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error setting VIP plan:", error);
    return { success: false, error: error.message };
  }
}
export async function removeUserVip(userId: string) {
  try {
    const { error } = await supabaseAdmin
      .from("users")
      .update({
        vip_level: 0,
        vip_until: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", userId);
    if (error) throw error;
    await supabaseAdmin
      .from("user_inventory")
      .update({ is_equipped: false, expires_at: new Date().toISOString() })
      .eq("user_id", userId)
      .eq("source", "vip_reward");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.vip_remove",
      targetType: "user",
      targetId: userId,
      summary: `Removed VIP from ${who}`,
    });
    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error("Error removing VIP:", error);
    return { success: false, error: error.message };
  }
}
async function ensureShopCategory(name: string): Promise<string> {
  const { data: rows } = await supabaseAdmin
    .from("shop_categories")
    .select("id, name")
    .ilike("name", `%${name}%`)
    .limit(20);
  const exact = (rows ?? []).find((r) => String(r.name).toLowerCase() === name.toLowerCase());
  if (exact?.id) return String(exact.id);
  if (rows?.[0]?.id) return String(rows[0].id);
  const { data: created, error } = await supabaseAdmin
    .from("shop_categories")
    .insert({ name })
    .select("id")
    .single();
  if (error) throw error;
  return String(created.id);
}
export async function uploadAndGrantBadgeOrTitle(formData: FormData) {
  try {
    const userId = String(formData.get("userId") || "");
    const kind = String(formData.get("kind") || "badge");
    const name = String(formData.get("name") || "").trim();
    const fileEntry = formData.get("file");
    if (!userId) throw new Error("User required");
    if (!name) throw new Error("Name is required");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("Upload an image");
    }
    const uploadFd = new FormData();
    uploadFd.append("file", fileEntry);
    uploadFd.append("kind", kind === "title" ? "title" : "badge");
    const uploaded = await uploadUserMedia(uploadFd);
    if (!uploaded.success || !("url" in uploaded) || !uploaded.url) {
      throw new Error(uploaded.error || "Upload failed");
    }
    const categoryName = kind === "title" ? "VIP Titles" : "Medal";
    const categoryId = await ensureShopCategory(categoryName);
    const { data: item, error: itemErr } = await supabaseAdmin
      .from("shop_items")
      .insert({
        name,
        category_id: categoryId,
        image_url: uploaded.url,
        price_coins: 0,
        is_active: true,
        is_for_sale: false,
        source_type: kind === "title" ? "vip" : "medal",
      })
      .select("id")
      .single();
    if (itemErr) throw itemErr;
    const grant = await grantInventoryItem(userId, String(item.id), {
      equip: false,
    });
    if (!grant.success) throw new Error(grant.error || "Grant failed");
    revalidateProfilePaths(userId);
    return { success: true as const, itemId: String(item.id) };
  } catch (error: any) {
    console.error("Error uploadAndGrantBadgeOrTitle:", error);
    return { success: false as const, error: error.message as string };
  }
}
