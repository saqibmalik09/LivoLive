import { supabaseAdmin } from '@/lib/supabase';
import { CountryFlag } from '@/components/CountryFlag';
import { MasterUserOps } from '@/components/MasterUserOps';
import { ArrowLeft, User } from 'lucide-react';
import Link from 'next/link';
import { notFound } from 'next/navigation';

interface UserDetailPageProps {
  params: Promise<{ id: string }>;
}

function catName(item: any): string {
  const cat = item?.shop_categories;
  if (Array.isArray(cat)) return String(cat[0]?.name ?? '');
  return String(cat?.name ?? '');
}

export default async function UserDetailPage({ params }: UserDetailPageProps) {
  const { id } = await params;

  const { data: user, error } = await supabaseAdmin
    .from('users')
    .select('*')
    .eq('id', id)
    .single();

  if (error || !user) notFound();

  const [vipPlansRes, shopItemsRes, hostRoomRes] = await Promise.all([
    supabaseAdmin
      .from('vip_plans')
      .select('id, level, name, duration_days')
      .gte('level', 1)
      .lte('level', 6)
      .order('level', { ascending: true }),
    supabaseAdmin
      .from('shop_items')
      .select('id, name, image_url, shop_categories(name)')
      .eq('is_active', true)
      .order('name', { ascending: true })
      .limit(500),
    supabaseAdmin
      .from('rooms')
      .select('id, image_url, background_url, is_pinned, pin_order')
      .eq('host_id', id)
      .maybeSingle(),
  ]);

  const lastDeviceId = (user.last_device_id as string | null) ?? null;
  const lastAndroidId = (user.last_android_id as string | null) ?? null;
  const fcmToken = (user.fcm_token as string | null) ?? null;
  let deviceBanned = false;

  const signalChecks: Array<{ signal_type: string; signal_value: string }> = [];
  if (lastDeviceId && lastDeviceId.trim().length >= 8) {
    signalChecks.push({ signal_type: 'install_id', signal_value: lastDeviceId.trim() });
  }
  if (lastAndroidId && lastAndroidId.trim().length >= 8) {
    signalChecks.push({ signal_type: 'android_id', signal_value: lastAndroidId.trim() });
  }
  if (fcmToken && fcmToken.trim().length >= 20) {
    signalChecks.push({ signal_type: 'fcm_token', signal_value: fcmToken.trim() });
  }

  for (const sig of signalChecks) {
    const { data: banRow } = await supabaseAdmin
      .from('banned_device_signals')
      .select('id')
      .eq('signal_type', sig.signal_type)
      .eq('signal_value', sig.signal_value)
      .eq('is_active', true)
      .maybeSingle();
    if (banRow) {
      deviceBanned = true;
      break;
    }
  }

  if (!deviceBanned && lastDeviceId) {
    const { data: banRow } = await supabaseAdmin
      .from('banned_devices')
      .select('id')
      .eq('device_id', lastDeviceId)
      .eq('is_active', true)
      .maybeSingle();
    if (banRow) deviceBanned = true;
  }

  const vipPlans = (vipPlansRes.data ?? []).map((p: any) => ({
    id: String(p.id),
    level: Number(p.level ?? 0),
    name: String(p.name ?? `VIP ${p.level}`),
    durationDays: Number(p.duration_days ?? 30),
  }));

  const shopItems = (shopItemsRes.data ?? []).map((item: any) => ({
    id: String(item.id),
    name: String(item.name ?? 'Item'),
    imageUrl: item.image_url ? String(item.image_url) : null,
    categoryName: catName(item) || 'Unknown',
  }));

  const room = hostRoomRes.data
    ? {
        id: String(hostRoomRes.data.id),
        imageUrl: hostRoomRes.data.image_url ? String(hostRoomRes.data.image_url) : null,
        backgroundUrl: hostRoomRes.data.background_url
          ? String(hostRoomRes.data.background_url)
          : null,
        isPinned: (hostRoomRes.data as any).is_pinned === true,
        pinOrder: Number((hostRoomRes.data as any).pin_order ?? 0),
      }
    : null;

  return (
    <div className="space-y-8 pb-32">
      <Link
        href="/users"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Users</span>
      </Link>

      <div className="grid grid-cols-1 xl:grid-cols-[1fr_420px] gap-8">
        <div className="glass-card p-8 space-y-6">
          <div className="flex items-start gap-5">
            <div className="w-20 h-20 rounded-3xl bg-purple-500/20 border border-white/10 overflow-hidden flex items-center justify-center shrink-0">
              {user.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={user.avatar_url}
                  alt={user.username}
                  className="w-full h-full object-cover"
                />
              ) : (
                <User size={32} className="text-purple-400" />
              )}
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-3 flex-wrap">
                <CountryFlag code={user.country_code} size={28} />
                <h1 className="text-4xl font-black tracking-tight truncate">{user.username}</h1>
              </div>
              <p className="text-white/40 mt-2 font-mono text-sm">
                UID {user.short_id ?? '—'} · {user.id}
              </p>
              <div className="flex flex-wrap gap-3 mt-4 text-xs font-bold uppercase tracking-widest">
                <span className="px-3 py-1 rounded-full bg-purple-500/10 text-purple-300 border border-purple-500/20">
                  Lvl {user.user_level ?? 0}
                </span>
                <span className="px-3 py-1 rounded-full bg-amber-500/10 text-amber-300 border border-amber-500/20">
                  VIP {user.vip_level ?? 0}
                </span>
                <span
                  className={`px-3 py-1 rounded-full border ${
                    user.is_banned
                      ? 'bg-red-500/10 text-red-300 border-red-500/20'
                      : 'bg-emerald-500/10 text-emerald-300 border-emerald-500/20'
                  }`}
                >
                  {user.is_banned ? 'Banned' : 'Active'}
                </span>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <Stat label="Coins" value={Number(user.coins || 0).toLocaleString()} />
            <Stat label="Diamonds" value={Number(user.diamonds || 0).toLocaleString()} />
            <Stat label="Wealth" value={Number(user.wealth_level || 0).toLocaleString()} />
            <Stat label="Charm" value={Number(user.charm_level || 0).toLocaleString()} />
          </div>
        </div>

        <MasterUserOps
          userId={user.id}
          username={String(user.username ?? '')}
          avatarUrl={user.avatar_url ? String(user.avatar_url) : null}
          isBanned={Boolean(user.is_banned)}
          banReason={user.ban_reason ? String(user.ban_reason) : null}
          lastDeviceId={lastDeviceId}
          deviceBanned={deviceBanned}
          vipLevel={Number(user.vip_level || 0)}
          vipUntil={user.vip_until ? String(user.vip_until) : null}
          vipPlans={vipPlans}
          shopItems={shopItems}
          room={room}
        />
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-white/5 border border-white/5 px-4 py-3">
      <p className="text-[10px] font-black uppercase tracking-widest text-white/40">{label}</p>
      <p className="font-black mt-1">{value}</p>
    </div>
  );
}
