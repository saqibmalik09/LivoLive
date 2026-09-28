'use client';

import { useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import {
  Ban,
  Crown,
  Gift,
  ImageIcon,
  Loader2,
  ShieldAlert,
  Smartphone,
  User,
} from 'lucide-react';
import { toast } from 'sonner';
import {
  banUserDevice,
  grantInventoryItem,
  removeUserVip,
  setUserVipPlan,
  toggleUserBan,
  unbanUserDevice,
  updateUserProfile,
  updateUserRoom,
  uploadUserMedia,
} from '@/app/users/actions';

type VipPlan = {
  id: string;
  level: number;
  name: string;
  durationDays: number;
};

type ShopItem = {
  id: string;
  name: string;
  imageUrl: string | null;
  categoryName: string;
};

type RoomInfo = {
  id: string;
  imageUrl: string | null;
  backgroundUrl: string | null;
  isPinned: boolean;
  pinOrder: number;
} | null;

export function MasterUserOps({
  userId,
  username,
  avatarUrl,
  isBanned,
  banReason,
  lastDeviceId,
  deviceBanned,
  vipLevel,
  vipUntil,
  vipPlans,
  shopItems,
  room,
}: {
  userId: string;
  username: string;
  avatarUrl: string | null;
  isBanned: boolean;
  banReason: string | null;
  lastDeviceId: string | null;
  deviceBanned: boolean;
  vipLevel: number;
  vipUntil: string | null;
  vipPlans: VipPlan[];
  shopItems: ShopItem[];
  room: RoomInfo;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [banNote, setBanNote] = useState(banReason ?? '');
  const [deviceNote, setDeviceNote] = useState('');
  const [name, setName] = useState(username);
  const [planId, setPlanId] = useState(vipPlans.find((p) => p.level === vipLevel)?.id ?? vipPlans[0]?.id ?? '');
  const [itemId, setItemId] = useState(shopItems[0]?.id ?? '');
  const [roomImage, setRoomImage] = useState(room?.imageUrl ?? '');
  const [roomBg, setRoomBg] = useState(room?.backgroundUrl ?? '');
  const [roomPinSlot, setRoomPinSlot] = useState(
    room?.isPinned && room.pinOrder >= 1 && room.pinOrder <= 3 ? String(room.pinOrder) : '0',
  );
  const avatarInput = useRef<HTMLInputElement>(null);

  const refresh = () => router.refresh();

  const run = (fn: () => Promise<{ success: boolean; error?: string }>, ok: string) => {
    startTransition(async () => {
      const res = await fn();
      if (!res.success) {
        toast.error(res.error || 'Failed');
        return;
      }
      toast.success(ok);
      refresh();
    });
  };

  return (
    <div className="space-y-6">
      <section className="glass-card p-6 space-y-4 border-red-500/20">
        <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2 text-red-300">
          <Ban size={16} /> Ban / Unban
        </h3>
        <p className="text-xs text-white/40">
          Status: {isBanned ? 'Banned' : 'Active'}
          {isBanned && banReason ? ` · ${banReason}` : ''}
        </p>
        { !isBanned && (
          <input
            value={banNote}
            onChange={(e) => setBanNote(e.target.value)}
            placeholder="Ban reason"
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-red-400/40"
          />
        )}
        <button
          type="button"
          disabled={pending}
          onClick={() =>
            run(
              () => toggleUserBan(userId, isBanned, banNote),
              isBanned ? 'User unbanned' : 'User banned',
            )
          }
          className="w-full py-3 rounded-xl font-black text-xs uppercase tracking-widest bg-red-500/15 text-red-300 border border-red-400/20 hover:bg-red-500 hover:text-black disabled:opacity-50"
        >
          {pending ? <Loader2 className="animate-spin mx-auto" size={16} /> : isBanned ? 'Unban user' : 'Ban user'}
        </button>
      </section>

      <section className="glass-card p-6 space-y-4 border-orange-500/20">
        <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2 text-orange-300">
          <Smartphone size={16} /> Device ban
        </h3>
        <p className="text-xs text-white/40">
          Device: {lastDeviceId ? `${lastDeviceId.slice(0, 12)}…` : 'none yet'} ·{' '}
          {deviceBanned ? 'Banned' : 'Not banned'}
        </p>
        {!deviceBanned && (
          <input
            value={deviceNote}
            onChange={(e) => setDeviceNote(e.target.value)}
            placeholder="Device ban reason"
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-orange-400/40"
          />
        )}
        <div className="grid grid-cols-2 gap-3">
          <button
            type="button"
            disabled={pending}
            onClick={() =>
              run(
                () => banUserDevice(userId, lastDeviceId ?? '', deviceNote),
                'Device banned',
              )
            }
            className="py-3 rounded-xl font-black text-[10px] uppercase tracking-widest bg-orange-500/15 text-orange-300 border border-orange-400/20 hover:bg-orange-500 hover:text-black disabled:opacity-50"
          >
            Ban device
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() =>
              run(() => unbanUserDevice(userId, lastDeviceId ?? ''), 'Device unbanned')
            }
            className="py-3 rounded-xl font-black text-[10px] uppercase tracking-widest bg-white/5 text-white/70 border border-white/10 hover:bg-white/10 disabled:opacity-50"
          >
            Unban device
          </button>
        </div>
      </section>

      <section className="glass-card p-6 space-y-4 border-amber-500/20">
        <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2 text-amber-300">
          <Crown size={16} /> VIP (levels 1–6)
        </h3>
        <p className="text-xs text-white/40">
          Current: L{vipLevel || 0}
          {vipUntil ? ` · until ${new Date(vipUntil).toLocaleDateString()}` : ''}
        </p>
        <select
          value={planId}
          onChange={(e) => setPlanId(e.target.value)}
          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-amber-400/40"
        >
          {vipPlans.map((p) => (
            <option key={p.id} value={p.id}>
              L{p.level} · {p.name} · {p.durationDays}d
            </option>
          ))}
        </select>
        <div className="grid grid-cols-2 gap-3">
          <button
            type="button"
            disabled={pending || !planId}
            onClick={() =>
              run(() => setUserVipPlan(userId, planId, { replaceExpiry: true }), 'VIP granted')
            }
            className="py-3 rounded-xl font-black text-[10px] uppercase tracking-widest bg-amber-500/15 text-amber-300 border border-amber-400/20 hover:bg-amber-500 hover:text-black disabled:opacity-50"
          >
            Grant VIP
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() => run(() => removeUserVip(userId), 'VIP removed')}
            className="py-3 rounded-xl font-black text-[10px] uppercase tracking-widest bg-white/5 text-white/70 border border-white/10 hover:bg-white/10 disabled:opacity-50"
          >
            Remove VIP
          </button>
        </div>
      </section>

      <section className="glass-card p-6 space-y-4">
        <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2 text-purple-300">
          <User size={16} /> Profile
        </h3>
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-purple-500/20 border border-white/10 overflow-hidden flex items-center justify-center">
            {avatarUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
            ) : (
              <User size={22} className="text-purple-400" />
            )}
          </div>
          <div className="flex-1 space-y-2">
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-purple-400/40"
            />
            <input
              ref={avatarInput}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                startTransition(async () => {
                  const fd = new FormData();
                  fd.append('file', file);
                  fd.append('kind', 'avatar');
                  const up = await uploadUserMedia(fd);
                  if (!up.success || !('url' in up) || !up.url) {
                    toast.error(up.error || 'Upload failed');
                    return;
                  }
                  const res = await updateUserProfile(userId, {
                    username: name,
                    avatar_url: up.url,
                  });
                  if (!res.success) toast.error(res.error || 'Failed');
                  else {
                    toast.success('Avatar updated');
                    refresh();
                  }
                });
              }}
            />
            <button
              type="button"
              disabled={pending}
              onClick={() => avatarInput.current?.click()}
              className="text-[10px] font-black uppercase tracking-widest text-purple-300"
            >
              Upload avatar
            </button>
          </div>
        </div>
        <button
          type="button"
          disabled={pending}
          onClick={() =>
            run(() => updateUserProfile(userId, { username: name }), 'Username saved')
          }
          className="w-full py-3 rounded-xl font-black text-xs uppercase tracking-widest bg-purple-500/15 text-purple-300 border border-purple-400/20 hover:bg-purple-500 hover:text-black disabled:opacity-50"
        >
          Save username
        </button>
      </section>

      {room && (
        <section className="glass-card p-6 space-y-4 border-blue-500/20">
          <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2 text-blue-300">
            <ImageIcon size={16} /> Room
          </h3>
          <input
            value={roomImage}
            onChange={(e) => setRoomImage(e.target.value)}
            placeholder="Room image_url"
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-blue-400/40"
          />
          <input
            value={roomBg}
            onChange={(e) => setRoomBg(e.target.value)}
            placeholder="Room background_url"
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-blue-400/40"
          />
          <select
            value={roomPinSlot}
            onChange={(e) => setRoomPinSlot(e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-amber-400/40"
          >
            <option value="0">Not pinned</option>
            <option value="1">Pin #1 — big left card</option>
            <option value="2">Pin #2 — top right</option>
            <option value="3">Pin #3 — bottom right</option>
          </select>
          <button
            type="button"
            disabled={pending}
            onClick={() =>
              run(
                () =>
                  updateUserRoom(userId, {
                    image_url: roomImage || null,
                    background_url: roomBg || null,
                    pin_slot: Number(roomPinSlot),
                  }),
                'Room updated',
              )
            }
            className="w-full py-3 rounded-xl font-black text-xs uppercase tracking-widest bg-blue-500/15 text-blue-300 border border-blue-400/20 hover:bg-blue-500 hover:text-black disabled:opacity-50"
          >
            Save room
          </button>
        </section>
      )}

      <section className="glass-card p-6 space-y-4 border-emerald-500/20">
        <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2 text-emerald-300">
          <Gift size={16} /> Grant shop item
        </h3>
        <select
          value={itemId}
          onChange={(e) => setItemId(e.target.value)}
          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm outline-none focus:border-emerald-400/40"
        >
          {shopItems.map((item) => (
            <option key={item.id} value={item.id}>
              {item.name} · {item.categoryName}
            </option>
          ))}
        </select>
        <button
          type="button"
          disabled={pending || !itemId}
          onClick={() =>
            run(() => grantInventoryItem(userId, itemId, { equip: true }), 'Item granted')
          }
          className="w-full py-3 rounded-xl font-black text-xs uppercase tracking-widest bg-emerald-500/15 text-emerald-300 border border-emerald-400/20 hover:bg-emerald-500 hover:text-black disabled:opacity-50 flex items-center justify-center gap-2"
        >
          <ShieldAlert size={14} />
          Grant & equip
        </button>
      </section>
    </div>
  );
}
