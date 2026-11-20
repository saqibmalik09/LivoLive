"use client";
import { useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { User, Layers, Sparkles, Home, Loader2, Upload, Trash2, Crown, Award } from "lucide-react";
import {
  updateUserProfile,
  uploadUserMedia,
  updateUserLevels,
  updateRoomLevel,
  grantInventoryItem,
  equipInventoryItem,
  unequipInventoryItem,
  removeInventoryItem,
  updateUserRoom,
  updateUserShortId,
  setUserVipPlan,
  removeUserVip,
  uploadAndGrantBadgeOrTitle,
} from "@/app/users/actions";
export type ShopCatalogItem = {
  id: string;
  name: string;
  imageUrl: string | null;
  categoryName: string;
  sourceType: string | null;
};
export type VipPlanOption = {
  id: string;
  level: number;
  name: string;
  durationDays: number;
  priceCoins: number;
  imageUrl: string | null;
};
export type InventoryRow = {
  id: string;
  itemId: string;
  isEquipped: boolean;
  expiresAt: string | null;
  name: string;
  imageUrl: string | null;
  categoryName: string;
  sourceType: string | null;
};
export type HostRoomInfo = {
  id: string;
  title: string | null;
  imageUrl: string | null;
  backgroundUrl: string | null;
  decorationId: string | null;
  currentLevel: number;
  totalExp: number;
  isPinned: boolean;
  pinOrder: number;
};
export type DecorationOption = {
  id: string;
  name: string;
  imageUrl: string | null;
};
type CosmeticTab = "all" | "frame" | "entrance" | "car" | "medal";
interface UserProfileAdminProps {
  userId: string;
  shortId: number | null;
  username: string;
  bio: string | null;
  avatarUrl: string | null;
  bannerUrl: string | null;
  userLevel: number;
  wealthLevel: number;
  wealthValue: number;
  charmLevel: number;
  charmValue: number;
  vipLevel: number;
  vipUntil: string | null;
  vipPlans: VipPlanOption[];
  inventory: InventoryRow[];
  frameCatalog: ShopCatalogItem[];
  entranceCatalog: ShopCatalogItem[];
  carCatalog: ShopCatalogItem[];
  medalCatalog: ShopCatalogItem[];
  titleCatalog: ShopCatalogItem[];
  hostRoom: HostRoomInfo | null;
  decorations: DecorationOption[];
}
function matchesTab(row: InventoryRow, tab: CosmeticTab): boolean {
  if (tab === "all") return true;
  const cat = row.categoryName.toLowerCase();
  const src = (row.sourceType ?? "").toLowerCase();
  if (tab === "frame") {
    return (
      cat.includes("photo frame") ||
      cat === "frame" ||
      (cat.includes("frame") && !cat.includes("card"))
    );
  }
  if (tab === "entrance") {
    return cat.includes("entrance");
  }
  if (tab === "car") {
    return cat === "car" || cat.includes("vehicle");
  }
  return src === "medal" || cat.includes("medal") || cat.includes("badge") || cat.includes("title");
}
function isBadgeOrTitleRow(row: InventoryRow): boolean {
  const cat = row.categoryName.toLowerCase();
  const src = (row.sourceType ?? "").toLowerCase();
  return src === "medal" || cat.includes("medal") || cat.includes("badge") || cat.includes("title");
}
function isExpired(expiresAt: string | null): boolean {
  if (!expiresAt) return false;
  return new Date(expiresAt).getTime() < Date.now();
}
function formatExpiry(expiresAt: string | null): string {
  if (!expiresAt) return "Permanent";
  const d = new Date(expiresAt);
  if (Number.isNaN(d.getTime())) return "—";
  if (d.getTime() < Date.now()) return "Expired";
  return `Until ${d.toLocaleDateString()}`;
}
export function UserProfileAdmin({
  userId,
  shortId,
  username,
  bio,
  avatarUrl,
  bannerUrl,
  userLevel,
  wealthLevel,
  wealthValue,
  charmLevel,
  charmValue,
  vipLevel,
  vipUntil,
  vipPlans,
  inventory,
  frameCatalog,
  entranceCatalog,
  carCatalog,
  medalCatalog,
  titleCatalog,
  hostRoom,
  decorations,
}: UserProfileAdminProps) {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);
  const [profileShortId, setProfileShortId] = useState(shortId != null ? String(shortId) : "");
  const [profileUsername, setProfileUsername] = useState(username);
  const [profileBio, setProfileBio] = useState(bio ?? "");
  const [profileAvatar, setProfileAvatar] = useState(avatarUrl ?? "");
  const [profileBanner, setProfileBanner] = useState(bannerUrl ?? "");
  const [vipPlanId, setVipPlanId] = useState("");
  const [replaceVipExpiry, setReplaceVipExpiry] = useState(true);
  const [badgeGrantId, setBadgeGrantId] = useState("");
  const [titleGrantId, setTitleGrantId] = useState("");
  const [newBadgeName, setNewBadgeName] = useState("");
  const [newTitleName, setNewTitleName] = useState("");
  const badgeFileRef = useRef<HTMLInputElement>(null);
  const titleFileRef = useRef<HTMLInputElement>(null);
  const [lvlUser, setLvlUser] = useState(String(userLevel));
  const [lvlWealth, setLvlWealth] = useState(String(wealthLevel));
  const [lvlWealthVal, setLvlWealthVal] = useState(String(wealthValue));
  const [lvlCharm, setLvlCharm] = useState(String(charmLevel));
  const [lvlCharmVal, setLvlCharmVal] = useState(String(charmValue));
  const [lvlRoom, setLvlRoom] = useState(String(hostRoom?.currentLevel ?? 1));
  const [lvlRoomExp, setLvlRoomExp] = useState(String(hostRoom?.totalExp ?? 0));
  const [cosmeticTab, setCosmeticTab] = useState<CosmeticTab>("all");
  const [grantItemId, setGrantItemId] = useState("");
  const [grantAndEquip, setGrantAndEquip] = useState(true);
  const [roomImage, setRoomImage] = useState(hostRoom?.imageUrl ?? "");
  const [roomBg, setRoomBg] = useState(hostRoom?.backgroundUrl ?? "");
  const [roomDecorationId, setRoomDecorationId] = useState(hostRoom?.decorationId ?? "");
  // Featured or not — the home position is assigned automatically, so there is
  // one pin control in the panel rather than a set of numbered slots.
  const [roomFeatured, setRoomFeatured] = useState(hostRoom?.isPinned === true);
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const bannerInputRef = useRef<HTMLInputElement>(null);
  const roomImageInputRef = useRef<HTMLInputElement>(null);
  const roomBgInputRef = useRef<HTMLInputElement>(null);
  const catalogForTab = useMemo(() => {
    if (cosmeticTab === "frame") return frameCatalog;
    if (cosmeticTab === "entrance") return entranceCatalog;
    if (cosmeticTab === "car") return carCatalog;
    if (cosmeticTab === "medal") return medalCatalog;
    return [];
  }, [cosmeticTab, frameCatalog, entranceCatalog, carCatalog, medalCatalog]);
  const ownedForTab = useMemo(
    () => inventory.filter((row) => matchesTab(row, cosmeticTab)),
    [inventory, cosmeticTab],
  );
  const tabCounts = useMemo(() => {
    const counts: Record<CosmeticTab, number> = {
      all: inventory.length,
      frame: 0,
      entrance: 0,
      car: 0,
      medal: 0,
    };
    for (const row of inventory) {
      if (matchesTab(row, "frame")) counts.frame += 1;
      if (matchesTab(row, "entrance")) counts.entrance += 1;
      if (matchesTab(row, "car")) counts.car += 1;
      if (matchesTab(row, "medal")) counts.medal += 1;
    }
    return counts;
  }, [inventory]);
  const equippedSummary = useMemo(
    () => inventory.filter((row) => row.isEquipped && !isExpired(row.expiresAt)),
    [inventory],
  );
  const ownedBadgesTitles = useMemo(() => inventory.filter(isBadgeOrTitleRow), [inventory]);
  const run = async (
    key: string,
    fn: () => Promise<{
      success: boolean;
      error?: string;
    }>,
  ) => {
    setLoading(key);
    try {
      const res = await fn();
      if (!res.success) alert(`Error: ${res.error}`);
      else router.refresh();
    } finally {
      setLoading(null);
    }
  };
  const handleUpload = async (
    file: File | undefined,
    kind: string,
    onUrl: (url: string) => void,
  ) => {
    if (!file) return;
    setLoading(`upload-${kind}`);
    try {
      const fd = new FormData();
      fd.append("file", file);
      fd.append("kind", kind);
      const res = await uploadUserMedia(fd);
      if (!res.success) {
        alert(`Upload failed: ${res.error}`);
        return;
      }
      onUrl(res.url);
    } finally {
      setLoading(null);
    }
  };
  const inputClass =
    "w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-cyan-500/50";
  const labelClass = "text-[10px] font-bold uppercase tracking-widest text-white/40";
  const btnClass =
    "px-6 py-3 rounded-2xl font-black text-xs uppercase tracking-[0.15em] transition-all flex items-center justify-center gap-2 bg-cyan-500/10 text-cyan-300 border border-cyan-400/20 hover:bg-cyan-500 hover:text-black disabled:opacity-50";
  return (
    <div className="space-y-6 mt-8">
      <div className="glass-card space-y-5">
        <div className="flex items-center gap-2 text-violet-300">
          <User size={18} />
          <span className="text-[10px] font-black uppercase tracking-widest">Profile</span>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <label className="block space-y-1.5">
            <span className={labelClass}>UID (short_id)</span>
            <div className="flex gap-2">
              <input
                type="number"
                min={1}
                className={inputClass}
                value={profileShortId}
                onChange={(e) => setProfileShortId(e.target.value)}
                placeholder="e.g. 100001"
              />
              <button
                type="button"
                className={btnClass}
                disabled={loading !== null || !profileShortId.trim()}
                onClick={() =>
                  run("short-id", () => updateUserShortId(userId, Number(profileShortId)))
                }
              >
                {loading === "short-id" ? <Loader2 size={14} className="animate-spin" /> : null}
                Update UID
              </button>
            </div>
          </label>
          <label className="block space-y-1.5">
            <span className={labelClass}>Username</span>
            <input
              className={inputClass}
              value={profileUsername}
              onChange={(e) => setProfileUsername(e.target.value)}
            />
          </label>
          <label className="block space-y-1.5 md:col-span-2">
            <span className={labelClass}>Bio</span>
            <textarea
              className={`${inputClass} min-h-[80px]`}
              value={profileBio}
              onChange={(e) => setProfileBio(e.target.value)}
            />
          </label>
          <label className="block space-y-1.5">
            <span className={labelClass}>Avatar URL</span>
            <div className="flex gap-2">
              <input
                className={inputClass}
                value={profileAvatar}
                onChange={(e) => setProfileAvatar(e.target.value)}
              />
              <button
                type="button"
                className={btnClass}
                disabled={loading !== null}
                onClick={() => avatarInputRef.current?.click()}
              >
                {loading === "upload-avatar" ? (
                  <Loader2 size={14} className="animate-spin" />
                ) : (
                  <Upload size={14} />
                )}
              </button>
              <input
                ref={avatarInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => handleUpload(e.target.files?.[0], "avatar", setProfileAvatar)}
              />
            </div>
            {profileAvatar ? (
              <img
                src={profileAvatar}
                alt=""
                className="mt-2 w-16 h-16 rounded-xl object-cover border border-white/10"
              />
            ) : null}
          </label>
          <label className="block space-y-1.5">
            <span className={labelClass}>Banner URL</span>
            <div className="flex gap-2">
              <input
                className={inputClass}
                value={profileBanner}
                onChange={(e) => setProfileBanner(e.target.value)}
              />
              <button
                type="button"
                className={btnClass}
                disabled={loading !== null}
                onClick={() => bannerInputRef.current?.click()}
              >
                {loading === "upload-banner" ? (
                  <Loader2 size={14} className="animate-spin" />
                ) : (
                  <Upload size={14} />
                )}
              </button>
              <input
                ref={bannerInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => handleUpload(e.target.files?.[0], "banner", setProfileBanner)}
              />
            </div>
            {profileBanner ? (
              <img
                src={profileBanner}
                alt=""
                className="mt-2 w-full h-20 rounded-xl object-cover border border-white/10"
              />
            ) : null}
          </label>
        </div>
        <button
          type="button"
          className={btnClass}
          disabled={loading !== null}
          onClick={() =>
            run("profile", () =>
              updateUserProfile(userId, {
                username: profileUsername,
                bio: profileBio,
                avatar_url: profileAvatar,
                banner_url: profileBanner,
              }),
            )
          }
        >
          {loading === "profile" ? <Loader2 size={14} className="animate-spin" /> : null}
          Save Profile
        </button>
      </div>

      <div className="glass-card space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2 text-amber-300">
            <Crown size={18} />
            <span className="text-[10px] font-black uppercase tracking-widest">VIP Plan</span>
          </div>
          <p className="text-xs text-white/50">
            Level <span className="text-amber-200 font-bold">{vipLevel || 0}</span>
            {vipUntil ? ` · until ${new Date(vipUntil).toLocaleString()}` : " · no active VIP"}
          </p>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-[1fr_auto] gap-3 items-end">
          <label className="block space-y-1.5">
            <span className={labelClass}>Assign / upgrade plan</span>
            <select
              className={inputClass}
              value={vipPlanId}
              onChange={(e) => setVipPlanId(e.target.value)}
            >
              <option value="">Select VIP plan…</option>
              {vipPlans.map((p) => (
                <option key={p.id} value={p.id}>
                  Lv.{p.level} — {p.name} ({p.durationDays}d)
                </option>
              ))}
            </select>
          </label>
          <label className="flex items-center gap-2 text-xs text-white/50 pb-3">
            <input
              type="checkbox"
              checked={replaceVipExpiry}
              onChange={(e) => setReplaceVipExpiry(e.target.checked)}
            />
            Reset expiry (off = stack days)
          </label>
        </div>
        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            className={btnClass}
            disabled={loading !== null || !vipPlanId}
            onClick={() => {
              const plan = vipPlans.find((p) => p.id === vipPlanId);
              if (!confirm(`Set VIP to ${plan?.name ?? "plan"} (Lv.${plan?.level})?`)) {
                return;
              }
              run("vip-set", () =>
                setUserVipPlan(userId, vipPlanId, {
                  replaceExpiry: replaceVipExpiry,
                }),
              );
            }}
          >
            {loading === "vip-set" ? <Loader2 size={14} className="animate-spin" /> : null}
            Apply VIP Plan
          </button>
          <button
            type="button"
            className="px-6 py-3 rounded-2xl font-black text-xs uppercase tracking-[0.15em] bg-rose-500/10 text-rose-300 border border-rose-400/20 hover:bg-rose-500 hover:text-black disabled:opacity-50"
            disabled={loading !== null || vipLevel <= 0}
            onClick={() => {
              if (!confirm("Remove VIP from this user?")) return;
              run("vip-remove", () => removeUserVip(userId));
            }}
          >
            {loading === "vip-remove" ? <Loader2 size={14} className="animate-spin" /> : null}
            Remove VIP
          </button>
        </div>
        <p className="text-[11px] text-white/30">
          Apply VIP free of charge (admin). Assets provision like purchase; VIP title chip follows
          plan level.
        </p>
      </div>

      <div className="glass-card space-y-5">
        <div className="flex items-center gap-2 text-fuchsia-300">
          <Award size={18} />
          <span className="text-[10px] font-black uppercase tracking-widest">Badges & Titles</span>
        </div>

        <div className="space-y-2 max-h-56 overflow-y-auto">
          {ownedBadgesTitles.length === 0 ? (
            <p className="text-sm text-white/30">Is user ke paas abhi koi badge/title nahi.</p>
          ) : (
            ownedBadgesTitles.map((row) => (
              <div
                key={row.id}
                className="flex items-center gap-3 p-3 rounded-xl bg-black/30 border border-white/5"
              >
                {row.imageUrl ? (
                  <img
                    src={row.imageUrl}
                    alt=""
                    className="w-10 h-10 rounded-lg object-contain bg-black/40"
                  />
                ) : (
                  <div className="w-10 h-10 rounded-lg bg-white/5" />
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold truncate">{row.name}</p>
                  <p className="text-[10px] text-white/35 uppercase tracking-wider">
                    {row.categoryName} · {formatExpiry(row.expiresAt)}
                  </p>
                </div>
                <button
                  type="button"
                  className="px-3 py-2 rounded-xl text-[10px] font-black uppercase tracking-wider bg-rose-500/10 text-rose-300 border border-rose-400/20 hover:bg-rose-500 hover:text-black disabled:opacity-50 flex items-center gap-1"
                  disabled={loading !== null}
                  onClick={() => {
                    if (!confirm(`Remove "${row.name}"?`)) return;
                    run(`rm-badge-${row.id}`, () => removeInventoryItem(row.id, userId));
                  }}
                >
                  <Trash2 size={12} />
                  Remove
                </button>
              </div>
            ))
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-3 rounded-2xl border border-white/5 p-4 bg-black/20">
            <p className={labelClass}>Grant existing badge / medal</p>
            <select
              className={inputClass}
              value={badgeGrantId}
              onChange={(e) => setBadgeGrantId(e.target.value)}
            >
              <option value="">Select badge…</option>
              {medalCatalog.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
            <button
              type="button"
              className={btnClass}
              disabled={loading !== null || !badgeGrantId}
              onClick={() =>
                run("grant-badge", async () => {
                  const res = await grantInventoryItem(userId, badgeGrantId);
                  if (res.success) setBadgeGrantId("");
                  return res;
                })
              }
            >
              Grant Badge
            </button>
            <div className="border-t border-white/5 pt-3 space-y-2">
              <p className={labelClass}>Upload new badge</p>
              <input
                className={inputClass}
                placeholder="Badge name"
                value={newBadgeName}
                onChange={(e) => setNewBadgeName(e.target.value)}
              />
              <input
                ref={badgeFileRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={async (e) => {
                  const file = e.target.files?.[0];
                  if (!file || !newBadgeName.trim()) {
                    alert("Badge name aur image dono chahiye");
                    e.target.value = "";
                    return;
                  }
                  setLoading("upload-badge");
                  try {
                    const fd = new FormData();
                    fd.append("userId", userId);
                    fd.append("kind", "badge");
                    fd.append("name", newBadgeName.trim());
                    fd.append("file", file);
                    const res = await uploadAndGrantBadgeOrTitle(fd);
                    if (!res.success) alert(`Error: ${res.error}`);
                    else {
                      setNewBadgeName("");
                      router.refresh();
                    }
                  } finally {
                    setLoading(null);
                    e.target.value = "";
                  }
                }}
              />
              <button
                type="button"
                className={btnClass}
                disabled={loading !== null || !newBadgeName.trim()}
                onClick={() => badgeFileRef.current?.click()}
              >
                {loading === "upload-badge" ? (
                  <Loader2 size={14} className="animate-spin" />
                ) : (
                  <Upload size={14} />
                )}
                Upload & Give Badge
              </button>
            </div>
          </div>

          <div className="space-y-3 rounded-2xl border border-white/5 p-4 bg-black/20">
            <p className={labelClass}>Grant existing title</p>
            <select
              className={inputClass}
              value={titleGrantId}
              onChange={(e) => setTitleGrantId(e.target.value)}
            >
              <option value="">Select title…</option>
              {titleCatalog.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
            <button
              type="button"
              className={btnClass}
              disabled={loading !== null || !titleGrantId}
              onClick={() =>
                run("grant-title", async () => {
                  const res = await grantInventoryItem(userId, titleGrantId);
                  if (res.success) setTitleGrantId("");
                  return res;
                })
              }
            >
              Grant Title
            </button>
            <div className="border-t border-white/5 pt-3 space-y-2">
              <p className={labelClass}>Upload new title</p>
              <input
                className={inputClass}
                placeholder="Title name"
                value={newTitleName}
                onChange={(e) => setNewTitleName(e.target.value)}
              />
              <input
                ref={titleFileRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={async (e) => {
                  const file = e.target.files?.[0];
                  if (!file || !newTitleName.trim()) {
                    alert("Title name aur image dono chahiye");
                    e.target.value = "";
                    return;
                  }
                  setLoading("upload-title");
                  try {
                    const fd = new FormData();
                    fd.append("userId", userId);
                    fd.append("kind", "title");
                    fd.append("name", newTitleName.trim());
                    fd.append("file", file);
                    const res = await uploadAndGrantBadgeOrTitle(fd);
                    if (!res.success) alert(`Error: ${res.error}`);
                    else {
                      setNewTitleName("");
                      router.refresh();
                    }
                  } finally {
                    setLoading(null);
                    e.target.value = "";
                  }
                }}
              />
              <button
                type="button"
                className={btnClass}
                disabled={loading !== null || !newTitleName.trim()}
                onClick={() => titleFileRef.current?.click()}
              >
                {loading === "upload-title" ? (
                  <Loader2 size={14} className="animate-spin" />
                ) : (
                  <Upload size={14} />
                )}
                Upload & Give Title
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="glass-card space-y-5">
        <div className="flex items-center gap-2 text-amber-300">
          <Layers size={18} />
          <span className="text-[10px] font-black uppercase tracking-widest">Levels</span>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
          {(
            [
              ["User level", lvlUser, setLvlUser],
              ["Wealth level", lvlWealth, setLvlWealth],
              ["Wealth value", lvlWealthVal, setLvlWealthVal],
              ["Charm level", lvlCharm, setLvlCharm],
              ["Charm value", lvlCharmVal, setLvlCharmVal],
            ] as const
          ).map(([label, value, setter]) => (
            <label key={label} className="block space-y-1.5">
              <span className={labelClass}>{label}</span>
              <input
                type="number"
                min={0}
                className={inputClass}
                value={value}
                onChange={(e) => setter(e.target.value)}
              />
            </label>
          ))}
          {hostRoom && (
            <>
              <label className="block space-y-1.5">
                <span className={labelClass}>Room level</span>
                <input
                  type="number"
                  min={0}
                  className={inputClass}
                  value={lvlRoom}
                  onChange={(e) => setLvlRoom(e.target.value)}
                />
              </label>
              <label className="block space-y-1.5">
                <span className={labelClass}>Room exp</span>
                <input
                  type="number"
                  min={0}
                  className={inputClass}
                  value={lvlRoomExp}
                  onChange={(e) => setLvlRoomExp(e.target.value)}
                />
              </label>
            </>
          )}
        </div>
        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            className={btnClass}
            disabled={loading !== null}
            onClick={() =>
              run("levels", () =>
                updateUserLevels(userId, {
                  user_level: Number(lvlUser),
                  wealth_level: Number(lvlWealth),
                  wealth_value: Number(lvlWealthVal),
                  charm_level: Number(lvlCharm),
                  charm_value: Number(lvlCharmVal),
                }),
              )
            }
          >
            {loading === "levels" ? <Loader2 size={14} className="animate-spin" /> : null}
            Save User Levels
          </button>
          {hostRoom && (
            <button
              type="button"
              className={btnClass}
              disabled={loading !== null}
              onClick={() =>
                run("room-level", () =>
                  updateRoomLevel(userId, {
                    current_level: Number(lvlRoom),
                    total_exp: Number(lvlRoomExp),
                  }),
                )
              }
            >
              {loading === "room-level" ? <Loader2 size={14} className="animate-spin" /> : null}
              Save Room Level
            </button>
          )}
        </div>
      </div>

      <div className="glass-card space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2 text-pink-300">
            <Sparkles size={18} />
            <span className="text-[10px] font-black uppercase tracking-widest">
              Cosmetics & Medals
            </span>
          </div>
          <p className="text-xs text-white/40">
            Owned: <span className="text-white/80 font-bold">{inventory.length}</span>
            {equippedSummary.length > 0 ? ` · Equipped: ${equippedSummary.length}` : ""}
          </p>
        </div>

        {equippedSummary.length > 0 && (
          <div className="rounded-2xl border border-emerald-400/20 bg-emerald-500/5 p-4 space-y-2">
            <p className={labelClass}>Currently equipped</p>
            <div className="flex flex-wrap gap-2">
              {equippedSummary.map((row) => (
                <div
                  key={`eq-${row.id}`}
                  className="flex items-center gap-2 rounded-xl bg-black/30 border border-white/10 px-3 py-2"
                >
                  {row.imageUrl ? (
                    <img src={row.imageUrl} alt="" className="w-8 h-8 rounded-lg object-cover" />
                  ) : (
                    <div className="w-8 h-8 rounded-lg bg-white/5" />
                  )}
                  <div className="min-w-0">
                    <p className="text-xs font-bold truncate max-w-[140px]">{row.name}</p>
                    <p className="text-[9px] text-white/35 uppercase tracking-wider">
                      {row.categoryName}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex flex-wrap gap-2">
          {(
            [
              ["all", "All"],
              ["frame", "Frame"],
              ["entrance", "Entrance"],
              ["car", "Car"],
              ["medal", "Medal"],
            ] as const
          ).map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => {
                setCosmeticTab(key);
                setGrantItemId("");
              }}
              className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest border transition-all ${
                cosmeticTab === key
                  ? "bg-pink-500/20 text-pink-200 border-pink-400/30"
                  : "bg-white/5 text-white/40 border-white/10 hover:text-white/70"
              }`}
            >
              {label}
              <span className="ml-1 opacity-60">({tabCounts[key]})</span>
            </button>
          ))}
        </div>

        <div className="space-y-2 max-h-80 overflow-y-auto">
          {ownedForTab.length === 0 ? (
            <p className="text-sm text-white/30">
              {cosmeticTab === "all"
                ? "Is user ke paas abhi koi inventory asset nahi."
                : "Is tab mein koi owned item nahi."}
            </p>
          ) : (
            ownedForTab.map((row) => {
              const expired = isExpired(row.expiresAt);
              return (
                <div
                  key={row.id}
                  className={`flex flex-col sm:flex-row sm:items-center gap-3 p-3 rounded-xl border ${
                    expired
                      ? "bg-rose-500/5 border-rose-400/20 opacity-70"
                      : row.isEquipped
                        ? "bg-emerald-500/10 border-emerald-400/20"
                        : "bg-black/30 border-white/5"
                  }`}
                >
                  <div className="flex items-center gap-3 flex-1 min-w-0">
                    {row.imageUrl ? (
                      <img
                        src={row.imageUrl}
                        alt=""
                        className="w-12 h-12 rounded-lg object-cover shrink-0"
                      />
                    ) : (
                      <div className="w-12 h-12 rounded-lg bg-white/5 shrink-0" />
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-bold truncate">{row.name}</p>
                      <p className="text-[10px] text-white/35 uppercase tracking-wider">
                        {row.categoryName}
                        {row.isEquipped ? " · Equipped" : ""}
                        {expired ? " · Expired" : ""}
                      </p>
                      <p className="text-[10px] text-white/25 mt-0.5">
                        {formatExpiry(row.expiresAt)}
                      </p>
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2 shrink-0">
                    {!expired && (
                      <button
                        type="button"
                        className="px-3 py-2 rounded-xl text-[10px] font-black uppercase tracking-wider bg-white/5 text-emerald-300 border border-white/10 hover:bg-emerald-500/20 disabled:opacity-50"
                        disabled={loading !== null}
                        onClick={() =>
                          run(`eq-${row.id}`, () =>
                            row.isEquipped
                              ? unequipInventoryItem(row.id, userId)
                              : equipInventoryItem(row.id, userId, row.categoryName),
                          )
                        }
                      >
                        {row.isEquipped ? "Unequip" : "Equip"}
                      </button>
                    )}
                    <button
                      type="button"
                      className="px-3 py-2 rounded-xl text-[10px] font-black uppercase tracking-wider bg-rose-500/10 text-rose-300 border border-rose-400/20 hover:bg-rose-500 hover:text-black disabled:opacity-50 flex items-center gap-1"
                      disabled={loading !== null}
                      onClick={() => {
                        if (!confirm(`Remove "${row.name}" from this user's inventory?`)) {
                          return;
                        }
                        run(`rm-${row.id}`, () => removeInventoryItem(row.id, userId));
                      }}
                    >
                      <Trash2 size={12} />
                      Remove
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {cosmeticTab !== "all" && (
          <div className="grid grid-cols-1 md:grid-cols-[1fr_auto_auto] gap-3 items-end border-t border-white/5 pt-4">
            <label className="block space-y-1.5">
              <span className={labelClass}>Grant from shop</span>
              <select
                className={inputClass}
                value={grantItemId}
                onChange={(e) => setGrantItemId(e.target.value)}
              >
                <option value="">Select item…</option>
                {catalogForTab.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.name}
                  </option>
                ))}
              </select>
            </label>
            {cosmeticTab !== "medal" && (
              <label className="flex items-center gap-2 text-xs text-white/50 pb-3">
                <input
                  type="checkbox"
                  checked={grantAndEquip}
                  onChange={(e) => setGrantAndEquip(e.target.checked)}
                />
                Equip
              </label>
            )}
            <button
              type="button"
              className={btnClass}
              disabled={loading !== null || !grantItemId}
              onClick={() =>
                run("grant", async () => {
                  const res = await grantInventoryItem(userId, grantItemId, {
                    equip: cosmeticTab !== "medal" && grantAndEquip,
                  });
                  if (res.success) setGrantItemId("");
                  return res;
                })
              }
            >
              {loading === "grant" ? <Loader2 size={14} className="animate-spin" /> : null}
              Grant
            </button>
          </div>
        )}
        {cosmeticTab === "all" && (
          <p className="text-xs text-white/30">
            Naya asset dene ke liye Frame / Entrance / Car / Medal tab kholo.
          </p>
        )}
      </div>

      {hostRoom ? (
        <div className="glass-card space-y-5">
          <div className="flex items-center gap-2 text-sky-300">
            <Home size={18} />
            <span className="text-[10px] font-black uppercase tracking-widest">
              Room — {hostRoom.title || "Untitled"}
            </span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <label className="block space-y-1.5">
              <span className={labelClass}>Room card / banner URL</span>
              {roomImage ? (
                <div className="aspect-[16/9] max-w-xs rounded-xl overflow-hidden border border-white/10 mb-2">
                  <img src={roomImage} alt="Room banner" className="w-full h-full object-cover" />
                </div>
              ) : null}
              <div className="flex gap-2">
                <input
                  className={inputClass}
                  value={roomImage}
                  onChange={(e) => setRoomImage(e.target.value)}
                />
                <button
                  type="button"
                  className={btnClass}
                  disabled={loading !== null}
                  onClick={() => roomImageInputRef.current?.click()}
                >
                  <Upload size={14} />
                </button>
                <input
                  ref={roomImageInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => handleUpload(e.target.files?.[0], "room_banner", setRoomImage)}
                />
              </div>
            </label>
            <label className="block space-y-1.5">
              <span className={labelClass}>Live background URL</span>
              <div className="flex gap-2">
                <input
                  className={inputClass}
                  value={roomBg}
                  onChange={(e) => setRoomBg(e.target.value)}
                />
                <button
                  type="button"
                  className={btnClass}
                  disabled={loading !== null}
                  onClick={() => roomBgInputRef.current?.click()}
                >
                  <Upload size={14} />
                </button>
                <input
                  ref={roomBgInputRef}
                  type="file"
                  accept="image/*,.svga"
                  className="hidden"
                  onChange={(e) => handleUpload(e.target.files?.[0], "room_bg", setRoomBg)}
                />
              </div>
            </label>
            <label className="block space-y-1.5 md:col-span-2">
              <span className={labelClass}>Decoration catalog</span>
              <select
                className={inputClass}
                value={roomDecorationId}
                onChange={(e) => setRoomDecorationId(e.target.value)}
              >
                <option value="">None</option>
                {decorations.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="block space-y-1.5 md:col-span-2">
              <span className={labelClass}>Feature on home</span>
              <select
                className={inputClass}
                value={roomFeatured ? "1" : "0"}
                onChange={(e) => setRoomFeatured(e.target.value === "1")}
              >
                <option value="0">Not featured</option>
                <option value="1">Featured on home</option>
              </select>
            </label>
          </div>
          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              className={btnClass}
              disabled={loading !== null}
              onClick={() =>
                run("room", () =>
                  updateUserRoom(userId, {
                    image_url: roomImage,
                    background_url: roomBg,
                    decoration_id: roomDecorationId || null,
                    is_pinned: roomFeatured,
                  }),
                )
              }
            >
              {loading === "room" ? <Loader2 size={14} className="animate-spin" /> : null}
              Save Room
            </button>
            <button
              type="button"
              className="px-6 py-3 rounded-2xl font-black text-xs uppercase tracking-[0.15em] bg-rose-500/10 text-rose-300 border border-rose-400/20 hover:bg-rose-500 hover:text-black disabled:opacity-50"
              disabled={loading !== null}
              onClick={() => {
                if (!confirm("Clear live background?")) return;
                setRoomBg("");
                run("clear-bg", () => updateUserRoom(userId, { background_url: null }));
              }}
            >
              Clear BG
            </button>
          </div>
        </div>
      ) : (
        <div className="glass-card text-sm text-white/30">
          No host room for this user — room banner/bg controls hidden.
        </div>
      )}
    </div>
  );
}
