'use server';

import { supabaseAdmin } from '@/lib/supabase';
import { auditUserLabel, logAdminAction } from '@/lib/admin-audit';
import { revalidatePath } from 'next/cache';

function revalidateUserPaths(userId: string, staffId?: string | null) {
  revalidatePath(`/users/${userId}`);
  revalidatePath('/users');
  revalidatePath('/staff');
  revalidatePath('/agencies');
  if (staffId) revalidatePath(`/staff/${staffId}`);
}

function revalidateProfilePaths(userId: string) {
  revalidatePath(`/users/${userId}`);
  revalidatePath('/users');
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
      .from('users')
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
      .eq('id', userId)
      .select('id, is_banned, ban_reason, banned_at');

    if (error) throw error;
    if (!data?.length) {
      throw new Error('User not found or ban update blocked');
    }

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: nextBanned ? 'user.ban' : 'user.unban',
      targetType: 'user',
      targetId: userId,
      summary: `${nextBanned ? 'Blocked' : 'Unblocked'} ${who}`,
      metadata: {
        is_banned: nextBanned,
        ban_reason: note,
      },
    });

    revalidatePath(`/users/${userId}`);
    revalidatePath('/users');
    return { success: true, data: data[0] };
  } catch (error: any) {
    console.error('Error toggling ban:', error);
    return { success: false, error: error.message };
  }
}

/** Ban all known device signals for this user (install UUID + ANDROID_ID + FCM). */
export async function banUserDevice(
  userId: string,
  deviceId: string,
  reason?: string | null,
) {
  try {
    const note = reason?.trim() || null;
    const now = new Date().toISOString();

    const { data: userRow, error: userErr } = await supabaseAdmin
      .from('users')
      .select('last_device_id, last_android_id, fcm_token')
      .eq('id', userId)
      .maybeSingle();
    if (userErr) throw userErr;

    const installId =
      (userRow?.last_device_id as string | null)?.trim() || deviceId?.trim() || '';
    const androidId = (userRow?.last_android_id as string | null)?.trim() || '';
    const fcmToken = (userRow?.fcm_token as string | null)?.trim() || '';

    const signals: Array<{ signal_type: string; signal_value: string }> = [];
    if (installId.length >= 8) {
      signals.push({ signal_type: 'install_id', signal_value: installId });
    }
    if (androidId.length >= 8) {
      signals.push({ signal_type: 'android_id', signal_value: androidId });
    }
    if (fcmToken.length >= 20) {
      signals.push({ signal_type: 'fcm_token', signal_value: fcmToken });
    }

    if (signals.length === 0) {
      throw new Error(
        'No device signals on this user yet (install id / ANDROID_ID / FCM). Ask them to open the app once.',
      );
    }

    const { error: sigErr } = await supabaseAdmin.from('banned_device_signals').upsert(
      signals.map((s) => ({
        ...s,
        reason: note,
        banned_at: now,
        last_user_id: userId,
        is_active: true,
      })),
      { onConflict: 'signal_type,signal_value' },
    );
    if (sigErr) throw sigErr;

    if (installId.length >= 8) {
      const { error } = await supabaseAdmin.from('banned_devices').upsert(
        {
          device_id: installId,
          reason: note,
          banned_at: now,
          last_user_id: userId,
          is_active: true,
        },
        { onConflict: 'device_id' },
      );
      if (error) throw error;
    }

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: 'user.device_ban',
      targetType: 'user',
      targetId: userId,
      summary: `Banned device signals for ${who}`,
      metadata: {
        signals: signals.map((s) => s.signal_type),
        reason: note,
      },
    });

    revalidatePath(`/users/${userId}`);
    revalidatePath('/users');
    return { success: true as const };
  } catch (error: any) {
    console.error('Error banning device:', error);
    return { success: false as const, error: error.message };
  }
}

export async function unbanUserDevice(userId: string, deviceId: string) {
  try {
    const { data: userRow, error: userErr } = await supabaseAdmin
      .from('users')
      .select('last_device_id, last_android_id, fcm_token')
      .eq('id', userId)
      .maybeSingle();
    if (userErr) throw userErr;

    const installId =
      (userRow?.last_device_id as string | null)?.trim() || deviceId?.trim() || '';
    const androidId = (userRow?.last_android_id as string | null)?.trim() || '';
    const fcmToken = (userRow?.fcm_token as string | null)?.trim() || '';

    const { error: byUserErr } = await supabaseAdmin
      .from('banned_device_signals')
      .update({ is_active: false })
      .eq('last_user_id', userId)
      .eq('is_active', true);
    if (byUserErr) throw byUserErr;

    const pairs: Array<{ signal_type: string; signal_value: string }> = [];
    if (installId.length >= 8) {
      pairs.push({ signal_type: 'install_id', signal_value: installId });
    }
    if (androidId.length >= 8) {
      pairs.push({ signal_type: 'android_id', signal_value: androidId });
    }
    if (fcmToken.length >= 20) {
      pairs.push({ signal_type: 'fcm_token', signal_value: fcmToken });
    }

    for (const p of pairs) {
      const { error } = await supabaseAdmin
        .from('banned_device_signals')
        .update({ is_active: false })
        .eq('signal_type', p.signal_type)
        .eq('signal_value', p.signal_value);
      if (error) throw error;
    }

    if (installId) {
      const { error } = await supabaseAdmin
        .from('banned_devices')
        .update({ is_active: false })
        .eq('device_id', installId);
      if (error) throw error;
    }

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: 'user.device_unban',
      targetType: 'user',
      targetId: userId,
      summary: `Unbanned device signals for ${who}`,
      metadata: {
        signals: pairs.map((s) => s.signal_type),
        device_id: installId || null,
      },
    });

    revalidatePath(`/users/${userId}`);
    revalidatePath('/users');
    return { success: true as const };
  } catch (error: any) {
    console.error('Error unbanning device:', error);
    return { success: false as const, error: error.message };
  }
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
      if (!name) throw new Error('Username is required');
      payload.username = name;
    }
    if (data.bio !== undefined) payload.bio = data.bio?.trim() || null;
    if (data.avatar_url !== undefined) {
      payload.avatar_url = data.avatar_url?.trim() || null;
    }
    if (data.banner_url !== undefined) {
      payload.banner_url = data.banner_url?.trim() || null;
    }

    const { error } = await supabaseAdmin.from('users').update(payload).eq('id', userId);
    if (error) throw error;

    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error('Error updating profile:', error);
    return { success: false, error: error.message };
  }
}

export async function uploadUserMedia(formData: FormData) {
  try {
    const fileEntry = formData.get('file');
    const kind = String(formData.get('kind') || 'avatar');
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error('No file selected');
    }

    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : 'media.png';
    const fileType = fileEntry instanceof File ? fileEntry.type : '';
    const { resolveRankingAssetContentType, resolveRankingAssetExtension } = await import(
      '@/lib/ranking-asset-media'
    );
    const ext = resolveRankingAssetExtension(originalName, fileType);
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const safeBase = originalName
      .replace(/\s+/g, '_')
      .replace(/\.[^.]+$/, '')
      .slice(0, 40);
    const folder =
      kind === 'banner' || kind === 'room_banner' || kind === 'room_bg'
        ? 'users/media'
        : 'users/avatars';
    const fileName = `${folder}/${kind}-${Date.now()}-${safeBase}.${ext}`;

    const bucket = supabaseAdmin.storage.from('app_assets');
    const { error: uploadError } = await bucket.upload(fileName, buffer, {
      contentType,
      upsert: true,
    });
    if (uploadError) throw uploadError;

    const {
      data: { publicUrl },
    } = bucket.getPublicUrl(fileName);

    return { success: true as const, url: publicUrl };
  } catch (error: any) {
    console.error('Error uploading user media:', error);
    return { success: false as const, error: error.message as string };
  }
}

async function getHostRoomId(userId: string): Promise<string | null> {
  const { data } = await supabaseAdmin
    .from('rooms')
    .select('id')
    .eq('host_id', userId)
    .maybeSingle();
  return data?.id ?? null;
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
    if (!roomId) throw new Error('User has no host room');

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
        throw new Error('Pin slot must be 1, 2, 3, or 0');
      }
      if (slot === 0) {
        payload.is_pinned = false;
        payload.pin_order = 0;
      } else {
        await supabaseAdmin
          .from('rooms')
          .update({ is_pinned: false, pin_order: 0 })
          .eq('is_pinned', true)
          .eq('pin_order', slot)
          .neq('id', roomId);
        payload.is_pinned = true;
        payload.pin_order = slot;
      }
    } else if (data.is_pinned !== undefined) {
      if (!data.is_pinned) {
        payload.is_pinned = false;
        payload.pin_order = 0;
      } else {
        const { data: usedRows } = await supabaseAdmin
          .from('rooms')
          .select('pin_order')
          .eq('is_pinned', true)
          .gte('pin_order', 1)
          .lte('pin_order', 3);
        const used = new Set((usedRows ?? []).map((r: any) => Number(r.pin_order)));
        const free = [1, 2, 3].find((s) => !used.has(s));
        if (!free) throw new Error('All pin slots 1–3 are full');
        payload.is_pinned = true;
        payload.pin_order = free;
      }
    }
    if (Object.keys(payload).length === 0) {
      throw new Error('Nothing to update');
    }

    const { error } = await supabaseAdmin.from('rooms').update(payload).eq('id', roomId);
    if (error) throw error;

    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error('Error updating room:', error);
    return { success: false, error: error.message };
  }
}

async function unequipSameCategory(userId: string, categoryName: string) {
  const { data: rows } = await supabaseAdmin
    .from('user_inventory')
    .select('id, shop_items(shop_categories(name))')
    .eq('user_id', userId);

  const ids = (rows ?? [])
    .filter((row: any) => {
      const item = Array.isArray(row.shop_items) ? row.shop_items[0] : row.shop_items;
      const catRaw = item?.shop_categories;
      const cat = Array.isArray(catRaw)
        ? String(catRaw[0]?.name ?? '').toLowerCase()
        : String(catRaw?.name ?? '').toLowerCase();
      return cat === categoryName.toLowerCase();
    })
    .map((row: any) => row.id as string);

  if (ids.length > 0) {
    await supabaseAdmin.from('user_inventory').update({ is_equipped: false }).in('id', ids);
  }
}

async function equipInventoryRow(
  inventoryId: string,
  userId: string,
  categoryName: string,
) {
  const { error: rpcError } = await supabaseAdmin.rpc('equip_user_asset', {
    p_asset_id: inventoryId,
    p_user_id: userId,
    p_category_name: categoryName,
  });

  if (!rpcError) return;

  await unequipSameCategory(userId, categoryName);
  const { error } = await supabaseAdmin
    .from('user_inventory')
    .update({ is_equipped: true })
    .eq('id', inventoryId)
    .eq('user_id', userId);
  if (error) throw error;
}

export async function grantInventoryItem(
  userId: string,
  itemId: string,
  opts?: { equip?: boolean },
) {
  try {
    if (!itemId) throw new Error('Select a shop item');

    const { data: item, error: itemErr } = await supabaseAdmin
      .from('shop_items')
      .select('id, name, shop_categories(name)')
      .eq('id', itemId)
      .maybeSingle();
    if (itemErr) throw itemErr;
    if (!item) throw new Error('Shop item not found');

    const { data: existing } = await supabaseAdmin
      .from('user_inventory')
      .select('id')
      .eq('user_id', userId)
      .eq('item_id', itemId)
      .maybeSingle();

    let inventoryId = existing?.id as string | undefined;

    if (!inventoryId) {
      const permanentExpiry = '9999-12-31T00:00:00.000Z';
      const baseRow = {
        user_id: userId,
        item_id: itemId,
        is_equipped: false,
        expires_at: permanentExpiry,
      };
      let inserted: { id: string } | null = null;
      let error: { message?: string } | null = null;

      ({ data: inserted, error } = await supabaseAdmin
        .from('user_inventory')
        .insert({ ...baseRow, source: 'admin' })
        .select('id')
        .single());

      if (error && /source/i.test(error.message ?? '')) {
        ({ data: inserted, error } = await supabaseAdmin
          .from('user_inventory')
          .insert(baseRow)
          .select('id')
          .single());
      }
      if (error) throw error;
      inventoryId = inserted!.id;
    }

    if (opts?.equip && inventoryId) {
      const catRaw = item.shop_categories as
        | { name?: string }
        | { name?: string }[]
        | null;
      const catName = Array.isArray(catRaw)
        ? catRaw[0]?.name ?? 'Unknown'
        : catRaw?.name ?? 'Unknown';
      await equipInventoryRow(inventoryId, userId, catName);
    }

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: 'user.inventory_grant',
      targetType: 'user',
      targetId: userId,
      summary: `Granted ${item.name} to ${who}`,
      metadata: { item_id: itemId, equip: !!opts?.equip },
    });

    revalidateProfilePaths(userId);
    revalidatePath('/shop');
    return { success: true };
  } catch (error: any) {
    console.error('Error granting inventory item:', error);
    return { success: false, error: error.message };
  }
}

export async function setUserVipPlan(
  userId: string,
  planId: string,
  opts?: { replaceExpiry?: boolean },
) {
  try {
    if (!planId) throw new Error('Select a VIP plan');

    const { data: plan, error: planErr } = await supabaseAdmin
      .from('vip_plans')
      .select('id, level, name, duration_days')
      .eq('id', planId)
      .maybeSingle();
    if (planErr) throw planErr;
    if (!plan) throw new Error('VIP plan not found');

    const duration = Math.max(1, Number(plan.duration_days) || 30);
    const level = Number(plan.level) || 0;
    if (level <= 0) throw new Error('Invalid VIP plan level');

    const { data: user, error: userErr } = await supabaseAdmin
      .from('users')
      .select('vip_until')
      .eq('id', userId)
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
      .from('users')
      .update({
        vip_level: level,
        vip_until: newUntil.toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId);
    if (error) throw error;

    const { error: provisionErr } = await supabaseAdmin.rpc('provision_user_assets', {
      p_user_id: userId,
    });
    if (provisionErr) {
      console.warn('provision_user_assets warning:', provisionErr.message);
    }

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: 'user.vip_set',
      targetType: 'user',
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
    console.error('Error setting VIP plan:', error);
    return { success: false, error: error.message };
  }
}

export async function removeUserVip(userId: string) {
  try {
    const { error } = await supabaseAdmin
      .from('users')
      .update({
        vip_level: 0,
        vip_until: null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId);
    if (error) throw error;

    await supabaseAdmin
      .from('user_inventory')
      .update({ is_equipped: false, expires_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('source', 'vip_reward');

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: 'user.vip_remove',
      targetType: 'user',
      targetId: userId,
      summary: `Removed VIP from ${who}`,
    });

    revalidateProfilePaths(userId);
    return { success: true };
  } catch (error: any) {
    console.error('Error removing VIP:', error);
    return { success: false, error: error.message };
  }
}

export async function transferHostToAgency(
  userId: string,
  toAgencyId: string,
  fromAgencyId?: string | null,
) {
  try {
    if (!userId) throw new Error('User required');
    if (!toAgencyId) throw new Error('Select destination agency');

    const { data: toAgency, error: toErr } = await supabaseAdmin
      .from('agencies')
      .select('id, name, is_active')
      .eq('id', toAgencyId)
      .maybeSingle();
    if (toErr) throw toErr;
    if (!toAgency) throw new Error('Destination agency not found');
    if (toAgency.is_active === false) throw new Error('Destination agency is inactive');

    const { data: membership, error: memErr } = await supabaseAdmin
      .from('agency_members')
      .select('id, agency_id, role')
      .eq('user_id', userId)
      .maybeSingle();
    if (memErr) throw memErr;

    if (membership?.agency_id === toAgencyId) {
      throw new Error('User is already in this agency');
    }

    if (fromAgencyId && membership && membership.agency_id !== fromAgencyId) {
      throw new Error('User is not in the selected source agency');
    }

    let fromAgencyName: string | null = null;
    const sourceId = membership?.agency_id ?? fromAgencyId ?? null;
    if (sourceId) {
      const { data: fromAgency } = await supabaseAdmin
        .from('agencies')
        .select('name')
        .eq('id', sourceId)
        .maybeSingle();
      fromAgencyName = fromAgency?.name ? String(fromAgency.name) : null;
    }

    if (membership) {
      const { error } = await supabaseAdmin
        .from('agency_members')
        .update({ agency_id: toAgencyId })
        .eq('id', membership.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from('agency_members').insert({
        agency_id: toAgencyId,
        user_id: userId,
        role: 'host',
      });
      if (error) throw error;
    }

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: 'agency.transfer_host',
      targetType: 'agency',
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
    revalidatePath('/agencies');
    return { success: true };
  } catch (error: any) {
    console.error('Error transferring host:', error);
    return { success: false, error: error.message };
  }
}

/** Move an agency under a different BD (sponsor_staff_id). */
export async function transferAgencyToBd(
  agencyId: string,
  newSponsorStaffId: string | null,
) {
  try {
    if (!agencyId) throw new Error('Agency required');

    const { data: agency, error: agencyErr } = await supabaseAdmin
      .from('agencies')
      .select('id, name, sponsor_staff_id')
      .eq('id', agencyId)
      .maybeSingle();
    if (agencyErr) throw agencyErr;
    if (!agency) throw new Error('Agency not found');

    let newSponsorLabel: string | null = null;
    if (newSponsorStaffId) {
      const { data: sponsor, error: sponsorErr } = await supabaseAdmin
        .from('business_staff')
        .select('id, staff_code, role, is_active, user:user_id(username)')
        .eq('id', newSponsorStaffId)
        .maybeSingle();
      if (sponsorErr) throw sponsorErr;
      if (!sponsor) throw new Error('BD staff not found');
      if (!sponsor.is_active) throw new Error('BD staff is not active');
      if (sponsor.role !== 'bd') {
        throw new Error('Sponsor must be a BD');
      }
      const u = Array.isArray(sponsor.user) ? sponsor.user[0] : sponsor.user;
      newSponsorLabel = `${sponsor.staff_code}${u?.username ? ` (@${u.username})` : ''}`;
    }

    if ((agency.sponsor_staff_id || null) === (newSponsorStaffId || null)) {
      throw new Error('Agency is already under this BD');
    }

    const { error } = await supabaseAdmin
      .from('agencies')
      .update({ sponsor_staff_id: newSponsorStaffId || null })
      .eq('id', agencyId);
    if (error) throw error;

    await logAdminAction({
      action: 'agency.change_sponsor',
      targetType: 'agency',
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
    revalidatePath('/agencies');
    if (agency.sponsor_staff_id) revalidatePath(`/staff/${agency.sponsor_staff_id}`);
    if (newSponsorStaffId) revalidatePath(`/staff/${newSponsorStaffId}`);
    return { success: true };
  } catch (error: any) {
    console.error('Error transferring agency to BD:', error);
    return { success: false, error: error.message };
  }
}
