import { supabaseAdmin } from "@/lib/supabase";
import { CountryFlag } from "@/components/CountryFlag";
import { UserActions } from "@/components/UserActions";
import { UserProfileAdmin } from "@/components/UserProfileAdmin";
import { UserRechargeHistory } from "@/components/UserRechargeHistory";
import { ResetUserPassword } from "@/components/ResetUserPassword";
import {
  User,
  Phone,
  Calendar,
  ArrowLeft,
  Star,
  Heart,
  Zap,
  ShieldCheck,
  Mail,
  KeyRound,
} from "lucide-react";
import { CopyButton } from "@/components/CopyButton";
import Link from "next/link";
import { notFound } from "next/navigation";
const RECHARGE_TYPES = [
  "recharge",
  "transfer_in",
  "seller_package",
  "invite_first_recharge",
  "invite_recharge_bonus",
] as const;
const LOGIN_PROVIDER_LABELS: Record<string, string> = {
  email: "Email / Password",
  phone: "Phone (OTP)",
  google: "Google",
  facebook: "Facebook",
  apple: "Apple",
};
function loginProviderLabel(provider: string) {
  const key = provider.toLowerCase();
  return LOGIN_PROVIDER_LABELS[key] ?? provider;
}
interface UserDetailPageProps {
  params: Promise<{
    id: string;
  }>;
}
function catName(item: any): string {
  const cat = item?.shop_categories;
  if (Array.isArray(cat)) return String(cat[0]?.name ?? "");
  return String(cat?.name ?? "");
}
function isFrameItem(item: any): boolean {
  const cat = catName(item).toLowerCase();
  const name = String(item?.name ?? "").toLowerCase();
  return (
    cat.includes("photo frame") ||
    cat === "frame" ||
    (cat.includes("frame") && !cat.includes("card") && !name.includes("card"))
  );
}
function isEntranceItem(item: any): boolean {
  const cat = catName(item).toLowerCase();
  return (
    cat.includes("entrance") ||
    String(item?.name ?? "")
      .toLowerCase()
      .includes("entrance")
  );
}
function isCarItem(item: any): boolean {
  const cat = catName(item).toLowerCase();
  return cat === "car" || cat.includes("vehicle");
}
function isMedalItem(item: any): boolean {
  const cat = catName(item).toLowerCase();
  const src = String(item?.source_type ?? "").toLowerCase();
  return src === "medal" || cat.includes("medal") || cat.includes("badge");
}
function isTitleItem(item: any): boolean {
  const cat = catName(item).toLowerCase();
  const name = String(item?.name ?? "").toLowerCase();
  return (
    cat.includes("vip title") ||
    cat.includes("titles") ||
    (cat.includes("title") && !cat.includes("subtitle")) ||
    name.includes("vip title")
  );
}
function mapShopItem(item: any) {
  return {
    id: String(item.id),
    name: String(item.name ?? "Item"),
    imageUrl: item.image_url ? String(item.image_url) : null,
    categoryName: catName(item) || "Unknown",
    sourceType: item.source_type != null ? String(item.source_type) : null,
  };
}
export default async function UserDetailPage({ params }: UserDetailPageProps) {
  const { id } = await params;
  const { data: user, error } = await supabaseAdmin.from("users").select("*").eq("id", id).single();
  const { data: cpData } = await supabaseAdmin
    .from("couples")
    .select("cp_level")
    .or(`user1_id.eq.${id},user2_id.eq.${id}`)
    .single();
  const cpLevel = cpData?.cp_level || 0;
  if (error || !user) {
    notFound();
  }
  const [
    staffRes,
    ownedAgencyRes,
    hostMembershipsRes,
    superBdRes,
    bdAdminRes,
    bdRes,
    agenciesRes,
    inventoryRes,
    shopItemsRes,
    hostRoomRes,
    decorationsRes,
    vipPlansRes,
    rechargeRes,
    authUserRes,
  ] = await Promise.all([
    supabaseAdmin
      .from("business_staff")
      .select("id, role, staff_code")
      .eq("user_id", id)
      .eq("is_active", true)
      .maybeSingle(),
    supabaseAdmin
      .from("agencies")
      .select("id, name, agency_code, is_active")
      .eq("owner_id", id)
      .maybeSingle(),
    supabaseAdmin
      .from("agency_members")
      .select("agency_id, joined_at, agency:agency_id(id, name, agency_code, is_active)")
      .eq("user_id", id),
    supabaseAdmin
      .from("business_staff")
      .select("id, staff_code, user:user_id(username, short_id)")
      .eq("role", "super_bd")
      .eq("is_active", true)
      .order("created_at", { ascending: false }),
    supabaseAdmin
      .from("business_staff")
      .select("id, staff_code, user:user_id(username, short_id)")
      .in("role", ["county_admin", "bd_admin"])
      .eq("is_active", true)
      .order("created_at", { ascending: false }),
    supabaseAdmin
      .from("business_staff")
      .select("id, staff_code, user:user_id(username, short_id)")
      .eq("role", "bd")
      .eq("is_active", true)
      .order("created_at", { ascending: false }),
    supabaseAdmin
      .from("agencies")
      .select("id, name, agency_code, is_active")
      .eq("is_active", true)
      .order("name", { ascending: true }),
    supabaseAdmin
      .from("user_inventory")
      .select(
        "id, item_id, is_equipped, expires_at, shop_items(id, name, image_url, source_type, shop_categories(name))",
      )
      .eq("user_id", id)
      .order("created_at", { ascending: false }),
    supabaseAdmin
      .from("shop_items")
      .select("id, name, image_url, source_type, shop_categories(name)")
      .eq("is_active", true)
      .order("name", { ascending: true })
      .limit(500),
    supabaseAdmin
      .from("rooms")
      .select("id, title, image_url, background_url, decoration_id, is_pinned, pin_order")
      .eq("host_id", id)
      .maybeSingle(),
    supabaseAdmin
      .from("room_decorations")
      .select("id, name, image_url")
      .eq("is_active", true)
      .order("name", { ascending: true })
      .limit(200),
    supabaseAdmin
      .from("vip_plans")
      .select("id, level, name, duration_days, price_coins, image_url")
      .order("level", { ascending: true }),
    supabaseAdmin
      .from("transactions")
      .select("id, amount, transaction_type, currency_type, description, created_at")
      .eq("user_id", id)
      .in("transaction_type", [...RECHARGE_TYPES])
      .gt("amount", 0)
      .order("created_at", { ascending: false })
      .limit(100),
    supabaseAdmin.auth.admin.getUserById(id),
  ]);
  const authUser = authUserRes.data?.user ?? null;
  const loginProviders = Array.from(
    new Set(
      (authUser?.identities ?? [])
        .map((identity) => identity.provider)
        .filter((p): p is string => !!p),
    ),
  );
  const authEmail =
    authUser?.email?.trim() ||
    (authUser?.identities ?? [])
      .map((identity) => {
        const data = identity.identity_data as Record<string, unknown> | undefined;
        const email = data?.email;
        return typeof email === "string" ? email.trim() : "";
      })
      .find((email) => !!email) ||
    null;
  const authPhone =
    authUser?.phone?.trim() || (user.phone != null ? String(user.phone).trim() : "") || null;
  const lastSignInAt = authUser?.last_sign_in_at
    ? new Date(authUser.last_sign_in_at).toLocaleString()
    : null;
  let roomStats: {
    current_level?: number;
    total_exp?: number;
  } | null = null;
  if (hostRoomRes.data?.id) {
    const { data: stats } = await supabaseAdmin
      .from("room_stats")
      .select("current_level, total_exp")
      .eq("room_id", hostRoomRes.data.id)
      .maybeSingle();
    roomStats = stats;
  }
  const staffRow = staffRes.data;
  const ownedAgency = ownedAgencyRes.data;
  const lastDeviceId = (user.last_device_id as string | null) ?? null;
  const lastAndroidId = (user.last_android_id as string | null) ?? null;
  const fcmToken = (user.fcm_token as string | null) ?? null;
  let deviceBan: {
    reason: string | null;
    banned_at: string | null;
    matched: string | null;
  } | null = null;
  const signalChecks: Array<{
    signal_type: string;
    signal_value: string;
  }> = [];
  if (lastDeviceId && lastDeviceId.trim().length >= 8) {
    signalChecks.push({ signal_type: "install_id", signal_value: lastDeviceId.trim() });
  }
  if (lastAndroidId && lastAndroidId.trim().length >= 8) {
    signalChecks.push({ signal_type: "android_id", signal_value: lastAndroidId.trim() });
  }
  if (fcmToken && fcmToken.trim().length >= 20) {
    signalChecks.push({ signal_type: "fcm_token", signal_value: fcmToken.trim() });
  }
  for (const sig of signalChecks) {
    const { data: banRow } = await supabaseAdmin
      .from("banned_device_signals")
      .select("reason, banned_at, is_active, signal_type")
      .eq("signal_type", sig.signal_type)
      .eq("signal_value", sig.signal_value)
      .eq("is_active", true)
      .maybeSingle();
    if (banRow) {
      deviceBan = {
        reason: banRow.reason ?? null,
        banned_at: banRow.banned_at ?? null,
        matched: banRow.signal_type ?? sig.signal_type,
      };
      break;
    }
  }
  if (!deviceBan && lastDeviceId) {
    const { data: banRow } = await supabaseAdmin
      .from("banned_devices")
      .select("reason, banned_at, is_active")
      .eq("device_id", lastDeviceId)
      .eq("is_active", true)
      .maybeSingle();
    if (banRow) {
      deviceBan = {
        reason: banRow.reason ?? null,
        banned_at: banRow.banned_at ?? null,
        matched: "install_id",
      };
    }
  }
  const hostMemberships = (hostMembershipsRes.data ?? []).map((row: any) => {
    const agency = Array.isArray(row.agency) ? row.agency[0] : row.agency;
    return {
      agencyId: String(row.agency_id),
      agencyName: agency?.name ? String(agency.name) : "Agency",
      agencyCode: agency?.agency_code ? String(agency.agency_code) : null,
    };
  });
  const mapStaffOption = (rows: any[] | null) =>
    (rows ?? []).map((row) => {
      const u = Array.isArray(row.user) ? row.user[0] : row.user;
      return {
        id: String(row.id),
        staffCode: String(row.staff_code ?? ""),
        username: u?.username ? String(u.username) : "Staff",
        shortId: u?.short_id != null ? String(u.short_id) : null,
      };
    });
  const agencies = (agenciesRes.data ?? []).map((a) => ({
    id: String(a.id),
    name: String(a.name ?? "Agency"),
    agencyCode: a.agency_code != null ? String(a.agency_code) : null,
  }));
  const inventory = (inventoryRes.data ?? []).map((row: any) => {
    const item = Array.isArray(row.shop_items) ? row.shop_items[0] : row.shop_items;
    return {
      id: String(row.id),
      itemId: String(row.item_id),
      isEquipped: Boolean(row.is_equipped),
      expiresAt: row.expires_at ? String(row.expires_at) : null,
      name: String(item?.name ?? "Item"),
      imageUrl: item?.image_url ? String(item.image_url) : null,
      categoryName: catName(item) || "Unknown",
      sourceType: item?.source_type != null ? String(item.source_type) : null,
    };
  });
  const shopItems = shopItemsRes.data ?? [];
  const frameCatalog = shopItems.filter(isFrameItem).map(mapShopItem);
  const entranceCatalog = shopItems.filter(isEntranceItem).map(mapShopItem);
  const carCatalog = shopItems.filter(isCarItem).map(mapShopItem);
  const medalCatalog = shopItems.filter(isMedalItem).map(mapShopItem);
  const titleCatalog = shopItems.filter(isTitleItem).map(mapShopItem);
  const vipPlans = (vipPlansRes.data ?? []).map((p: any) => ({
    id: String(p.id),
    level: Number(p.level ?? 0),
    name: String(p.name ?? `VIP ${p.level}`),
    durationDays: Number(p.duration_days ?? 30),
    priceCoins: Number(p.price_coins ?? 0),
    imageUrl: p.image_url ? String(p.image_url) : null,
  }));
  let hostRoom = null;
  if (hostRoomRes.data) {
    const room = hostRoomRes.data as any;
    hostRoom = {
      id: String(room.id),
      title: room.title != null ? String(room.title) : null,
      imageUrl: room.image_url ? String(room.image_url) : null,
      backgroundUrl: room.background_url ? String(room.background_url) : null,
      decorationId: room.decoration_id ? String(room.decoration_id) : null,
      currentLevel: Number(roomStats?.current_level ?? 1),
      totalExp: Number(roomStats?.total_exp ?? 0),
      isPinned: room.is_pinned === true,
      pinOrder: Number(room.pin_order ?? 0),
    };
  }
  const decorations = (decorationsRes.data ?? []).map((d: any) => ({
    id: String(d.id),
    name: String(d.name ?? "Decoration"),
    imageUrl: d.image_url ? String(d.image_url) : null,
  }));
  const rechargeRows = (rechargeRes.data ?? []).map((r: any) => ({
    id: String(r.id),
    amount: Number(r.amount ?? 0),
    transactionType: String(r.transaction_type ?? ""),
    currencyType: String(r.currency_type ?? "coin"),
    description: r.description != null ? String(r.description) : null,
    createdAt: String(r.created_at),
  }));
  const rechargeTotal = rechargeRows.reduce((sum, r) => sum + r.amount, 0);
  return (
    <div className="space-y-10 pb-20">
      <Link
        href="/users"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Users</span>
      </Link>

      <div className="flex flex-col lg:flex-row gap-8 items-start">
        <div className="glass-card w-full lg:w-96 flex flex-col items-center text-center gap-6">
          <div className="relative group">
            <div className="absolute inset-0 bg-purple-500 blur-2xl opacity-20 group-hover:opacity-40 transition-opacity rounded-full" />
            <div className="w-32 h-32 rounded-3xl bg-black/40 border-2 border-white/10 flex items-center justify-center overflow-hidden relative z-10">
              {user.avatar_url ? (
                <img
                  src={user.avatar_url}
                  alt={user.username}
                  className="w-full h-full object-cover"
                />
              ) : (
                <User size={64} className="text-white/20" />
              )}
            </div>
            {user.vip_level > 0 && (
              <div className="absolute -bottom-2 -right-2 bg-amber-500 text-black px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-tighter shadow-xl z-20">
                VIP {user.vip_level}
              </div>
            )}
          </div>

          <div>
            <h2 className="text-3xl font-black tracking-tighter flex items-center justify-center gap-2">
              <CountryFlag code={user.country_code} size={28} />
              {user.username}
            </h2>
            <div className="flex items-center justify-center gap-2 mt-1">
              <p className="text-white/40 text-xs font-medium">UID: {user.short_id ?? "N/A"}</p>
              {user.short_id != null && <CopyButton text={String(user.short_id)} />}
            </div>
          </div>

          <div className="w-full grid grid-cols-2 gap-3 mt-4">
            <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
              <p className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] mb-1">
                User Level
              </p>
              <div className="flex items-center justify-center gap-2 text-purple-400 font-black">
                <Star size={14} fill="currentColor" />
                {user.user_level}
              </div>
            </div>
            <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
              <p className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] mb-1">
                Wealth Level
              </p>
              <div className="flex items-center justify-center gap-2 text-amber-400 font-black">
                <Zap size={14} fill="currentColor" />
                {user.wealth_level}
              </div>
            </div>
            <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
              <p className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] mb-1">
                Charm Level
              </p>
              <div className="flex items-center justify-center gap-2 text-pink-400 font-black">
                <Heart size={14} fill="currentColor" />
                {user.charm_level}
              </div>
            </div>
            <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
              <p className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] mb-1">
                CP Level
              </p>
              <div className="flex items-center justify-center gap-2 text-emerald-400 font-black">
                <Heart size={14} fill="currentColor" />
                {cpLevel}
              </div>
            </div>
          </div>
        </div>

        <div className="flex-1 space-y-8 w-full">
          <div className="glass-card">
            <h3 className="text-xl font-black flex items-center gap-2 mb-8">
              <ShieldCheck className="text-purple-400" />
              Account Details
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <DetailItem
                label="UID"
                value={user.short_id != null ? String(user.short_id) : "Not assigned"}
                icon={User}
              />
              <div className="flex flex-col gap-2">
                <span className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] flex items-center gap-2">
                  <KeyRound size={12} className="text-purple-400" />
                  Login Method
                </span>
                <div className="flex flex-wrap items-center gap-2 min-h-[38px]">
                  {loginProviders.length > 0 ? (
                    loginProviders.map((provider) => (
                      <span
                        key={provider}
                        className="inline-flex items-center px-3 py-1.5 rounded-full bg-purple-500/10 border border-purple-400/20 text-purple-300 text-[11px] font-black uppercase tracking-wider"
                      >
                        {loginProviderLabel(provider)}
                      </span>
                    ))
                  ) : (
                    <span className="font-bold text-sm text-white/40 tracking-tight">Unknown</span>
                  )}
                </div>
              </div>
              <DetailItem label="Email" value={authEmail || "Not provided"} icon={Mail} />
              <DetailItem label="Phone Number" value={authPhone || "Not provided"} icon={Phone} />
              <DetailItem
                label="Last Sign In"
                value={lastSignInAt || "Never / unknown"}
                icon={Calendar}
              />
              <div>
                <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-white/30 mb-2 flex items-center gap-2">
                  <Calendar size={14} className="text-purple-400" />
                  Country
                </p>
                <CountryFlag code={user.country_code} size={36} />
              </div>
              <DetailItem
                label="Joined Date"
                value={new Date(user.created_at).toLocaleDateString()}
                icon={Calendar}
              />
              <DetailItem
                label="Last Update"
                value={new Date(user.updated_at).toLocaleDateString()}
                icon={Calendar}
              />
              <div className="md:col-span-2">
                <DetailItem label="Biography" value={user.bio || "No bio set."} icon={User} />
              </div>
              <ResetUserPassword userId={user.id} userEmail={authEmail || null} />
            </div>
          </div>

          <UserProfileAdmin
            userId={user.id}
            shortId={user.short_id != null ? Number(user.short_id) : null}
            username={String(user.username ?? "")}
            bio={user.bio != null ? String(user.bio) : null}
            avatarUrl={user.avatar_url ? String(user.avatar_url) : null}
            bannerUrl={user.banner_url ? String(user.banner_url) : null}
            userLevel={Number(user.user_level ?? 0)}
            wealthLevel={Number(user.wealth_level ?? 0)}
            wealthValue={Number(user.wealth_value ?? 0)}
            charmLevel={Number(user.charm_level ?? 0)}
            charmValue={Number(user.charm_value ?? 0)}
            vipLevel={Number(user.vip_level ?? 0)}
            vipUntil={user.vip_until ? String(user.vip_until) : null}
            vipPlans={vipPlans}
            inventory={inventory}
            frameCatalog={frameCatalog}
            entranceCatalog={entranceCatalog}
            carCatalog={carCatalog}
            medalCatalog={medalCatalog}
            titleCatalog={titleCatalog}
            hostRoom={hostRoom}
            decorations={decorations}
          />

          <UserActions
            userId={user.id}
            initialCoins={Number(user.coins)}
            initialDiamonds={Number(user.diamonds)}
            initialResellerCoins={Number(user.reseller_coins ?? 0)}
            initialCashBalance={Number(user.cash_balance ?? 0)}
            initialShortId={user.short_id != null ? Number(user.short_id) : null}
            initialSpecialIdLevel={
              user.special_id_level != null ? Number(user.special_id_level) : null
            }
            initialCountryCode={user.country_code != null ? String(user.country_code) : null}
            isBanned={!!user.is_banned}
            banReason={user.ban_reason != null ? String(user.ban_reason) : null}
            lastDeviceId={lastDeviceId}
            lastAndroidId={lastAndroidId}
            hasFcmToken={!!(fcmToken && fcmToken.trim().length >= 20)}
            deviceBanned={!!deviceBan}
            deviceBanReason={deviceBan?.reason ?? null}
            deviceBanMatched={deviceBan?.matched ?? null}
            isReseller={user.is_reseller ?? false}
            staffId={staffRow?.id ?? null}
            staffRole={staffRow?.role ?? null}
            staffCode={staffRow?.staff_code ?? null}
            ownedAgency={
              ownedAgency
                ? {
                    id: String(ownedAgency.id),
                    name: String(ownedAgency.name ?? "Agency"),
                    agencyCode:
                      ownedAgency.agency_code != null ? String(ownedAgency.agency_code) : null,
                  }
                : null
            }
            hostMemberships={hostMemberships}
            superBdOptions={mapStaffOption(superBdRes.data)}
            bdAdminOptions={mapStaffOption(bdAdminRes.data)}
            bdOptions={mapStaffOption(bdRes.data)}
            agencies={agencies}
          />

          <UserRechargeHistory rows={rechargeRows} totalCoins={rechargeTotal} />
        </div>
      </div>
    </div>
  );
}
function DetailItem({ label, value, icon: Icon }: any) {
  return (
    <div className="flex flex-col gap-2">
      <span className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em]">{label}</span>
      <div className="flex items-center gap-3">
        <div className="p-2 bg-white/5 rounded-lg border border-white/5">
          <Icon size={14} className="text-white/40" />
        </div>
        <span className="font-bold text-sm tracking-tight">{value}</span>
      </div>
    </div>
  );
}
