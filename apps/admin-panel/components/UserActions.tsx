"use client";
import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Coins,
  Diamond,
  ShieldAlert,
  ShieldCheck,
  Loader2,
  BadgeDollarSign,
  Network,
  Sparkles,
  Globe2,
  ArrowLeftRight,
  Smartphone,
} from "lucide-react";
import {
  updateUserCurrency,
  updateUserCountry,
  toggleUserBan,
  banUserDevice,
  unbanUserDevice,
  toggleReseller,
  promoteToSuperBd,
  deactivateStaffRole,
  promoteToBdAdmin,
  promoteToBd,
  createAgencyForOwner,
  assignHostToAgency,
  removeHostFromAgency,
  transferHostToAgency,
  setUserSpecialId,
} from "@/app/users/actions";
import { ADMIN_COUNTRY_OPTIONS, normalizeCountryCode } from "@/lib/countryFlag";
import { CountryFlag } from "@/components/CountryFlag";
type StaffOption = {
  id: string;
  staffCode: string;
  username: string;
  shortId: string | null;
};
type AgencyOption = {
  id: string;
  name: string;
  agencyCode: string | null;
};
type HostMembership = {
  agencyId: string;
  agencyName: string;
  agencyCode: string | null;
};
type AssignRole = "super_bd" | "bd_admin" | "bd" | "agency_owner" | "host";
interface UserActionsProps {
  userId: string;
  initialCoins: number;
  initialDiamonds: number;
  initialResellerCoins: number;
  initialCashBalance: number;
  initialShortId: number | null;
  initialSpecialIdLevel: number | null;
  initialCountryCode: string | null;
  isBanned: boolean;
  banReason: string | null;
  lastDeviceId: string | null;
  lastAndroidId: string | null;
  hasFcmToken: boolean;
  deviceBanned: boolean;
  deviceBanReason: string | null;
  deviceBanMatched: string | null;
  isReseller: boolean;
  staffId: string | null;
  staffRole: string | null;
  staffCode: string | null;
  ownedAgency: AgencyOption | null;
  hostMemberships: HostMembership[];
  superBdOptions: StaffOption[];
  bdAdminOptions: StaffOption[];
  bdOptions: StaffOption[];
  agencies: AgencyOption[];
}
const staffRoleLabels: Record<string, string> = {
  super_bd: "Super Admin",
  county_admin: "County Admin",
  bd_admin: "County Admin",
  bd: "BD",
};
function staffLabel(opt: StaffOption) {
  const uid = opt.shortId ? ` · UID ${opt.shortId}` : "";
  return `${opt.username}${uid} · ${opt.staffCode}`;
}
export function UserActions({
  userId,
  initialCoins,
  initialDiamonds,
  initialResellerCoins,
  initialCashBalance,
  initialShortId,
  initialSpecialIdLevel,
  initialCountryCode,
  isBanned: initialIsBanned,
  banReason: initialBanReason,
  lastDeviceId,
  lastAndroidId,
  hasFcmToken,
  deviceBanned: initialDeviceBanned,
  deviceBanReason: initialDeviceBanReason,
  deviceBanMatched: initialDeviceBanMatched,
  isReseller,
  staffId,
  staffRole,
  staffCode,
  ownedAgency,
  hostMemberships,
  superBdOptions,
  bdAdminOptions,
  bdOptions,
  agencies,
}: UserActionsProps) {
  const router = useRouter();
  const [coins, setCoins] = useState(initialCoins);
  const [diamonds, setDiamonds] = useState(initialDiamonds);
  const [resellerCoins, setResellerCoins] = useState(initialResellerCoins);
  const [cashBalance, setCashBalance] = useState(initialCashBalance);
  const [shortId, setShortId] = useState<string>(
    initialShortId != null ? String(initialShortId) : "",
  );
  const [specialLevel, setSpecialLevel] = useState<string>(
    initialSpecialIdLevel != null ? String(initialSpecialIdLevel) : "0",
  );
  const [countryCode, setCountryCode] = useState<string>(
    normalizeCountryCode(initialCountryCode) ?? "",
  );
  const [isBanned, setIsBanned] = useState(initialIsBanned);
  const [banReason, setBanReason] = useState(initialBanReason ?? "");
  const [banNoteDraft, setBanNoteDraft] = useState("");
  const [showBanModal, setShowBanModal] = useState(false);
  const [deviceBanned, setDeviceBanned] = useState(initialDeviceBanned);
  const [deviceBanReason, setDeviceBanReason] = useState(initialDeviceBanReason ?? "");
  const [deviceBanMatched, setDeviceBanMatched] = useState(initialDeviceBanMatched ?? "");
  const [deviceNoteDraft, setDeviceNoteDraft] = useState("");
  const [showDeviceBanModal, setShowDeviceBanModal] = useState(false);
  const hasAnyDeviceSignal = !!(lastDeviceId || lastAndroidId || hasFcmToken);
  const [loading, setLoading] = useState<string | null>(null);
  const [assignRole, setAssignRole] = useState<AssignRole>("super_bd");
  const [parentStaffId, setParentStaffId] = useState("");
  const [agencyName, setAgencyName] = useState("");
  const [sponsorStaffId, setSponsorStaffId] = useState("");
  const [hostAgencyId, setHostAgencyId] = useState("");
  const [transferToAgencyId, setTransferToAgencyId] = useState("");
  const hasStaffRole = !!staffRole && !!staffId;
  const parentOptions = useMemo(() => {
    if (assignRole === "bd_admin") return superBdOptions;
    if (assignRole === "bd") return bdAdminOptions;
    return [];
  }, [assignRole, superBdOptions, bdAdminOptions]);
  const handleUpdate = async (
    type: "coins" | "diamonds" | "reseller_coins" | "cash_balance",
    value: number,
  ) => {
    setLoading(type);
    const res = await updateUserCurrency(userId, type, value);
    if (res.success) {
      if (type === "coins") setCoins(value);
      else if (type === "diamonds") setDiamonds(value);
      else if (type === "reseller_coins") setResellerCoins(value);
      else setCashBalance(value);
    } else {
      alert(`Error updating ${type}: ${res.error}`);
    }
    setLoading(null);
  };
  const applyBanToggle = async (note?: string | null) => {
    setLoading("ban");
    const res = await toggleUserBan(userId, isBanned, note);
    if (!res.success) {
      alert(`Error: ${res.error}`);
      setLoading(null);
      return;
    }
    const nextBanned = !isBanned;
    setIsBanned(nextBanned);
    setBanReason(nextBanned ? note?.trim() || "" : "");
    setShowBanModal(false);
    setBanNoteDraft("");
    setLoading(null);
    router.refresh();
  };
  const handleBanToggle = async () => {
    if (isBanned) {
      if (!confirm("Unban this user? They will regain app access immediately.")) {
        return;
      }
      await applyBanToggle(null);
      return;
    }
    setBanNoteDraft(banReason || "");
    setShowBanModal(true);
  };
  const applyDeviceBan = async (note?: string | null) => {
    if (!hasAnyDeviceSignal) {
      alert("This user has no registered device signals yet. Ask them to open the app once.");
      return;
    }
    setLoading("device_ban");
    const res = await banUserDevice(userId, lastDeviceId ?? "", note);
    if (!res.success) {
      alert(`Error: ${res.error}`);
      setLoading(null);
      return;
    }
    setDeviceBanned(true);
    setDeviceBanReason(note?.trim() || "");
    setDeviceBanMatched("multi");
    setShowDeviceBanModal(false);
    setDeviceNoteDraft("");
    setLoading(null);
    router.refresh();
  };
  const handleDeviceBanToggle = async () => {
    if (!hasAnyDeviceSignal && !deviceBanned) {
      alert("This user has no registered device signals yet. Ask them to open the app once.");
      return;
    }
    if (deviceBanned) {
      if (
        !confirm(
          "Unban this device? Any account matching install / ANDROID_ID / FCM can use the app again.",
        )
      ) {
        return;
      }
      setLoading("device_ban");
      const res = await unbanUserDevice(userId, lastDeviceId ?? "");
      if (!res.success) {
        alert(`Error: ${res.error}`);
        setLoading(null);
        return;
      }
      setDeviceBanned(false);
      setDeviceBanReason("");
      setDeviceBanMatched("");
      setLoading(null);
      router.refresh();
      return;
    }
    setDeviceNoteDraft(deviceBanReason || "");
    setShowDeviceBanModal(true);
  };
  const handleResellerToggle = async () => {
    setLoading("reseller");
    const res = await toggleReseller(userId, isReseller);
    if (!res.success) {
      alert(`Error: ${res.error}`);
    } else {
      router.refresh();
    }
    setLoading(null);
  };
  const handleAssignRole = async () => {
    setLoading("role");
    try {
      let res: {
        success: boolean;
        error?: string;
      };
      if (assignRole === "super_bd") {
        if (hasStaffRole) {
          alert("User already has an active staff role. Remove it first.");
          return;
        }
        if (!confirm("Make this user Super Admin?")) return;
        res = await promoteToSuperBd(userId);
      } else if (assignRole === "bd_admin") {
        if (hasStaffRole) {
          alert("User already has an active staff role. Remove it first.");
          return;
        }
        if (!parentStaffId) {
          alert("Select a Super Admin parent");
          return;
        }
        if (!confirm("Make this user a County Admin under the selected Super Admin?")) return;
        res = await promoteToBdAdmin(userId, parentStaffId);
      } else if (assignRole === "bd") {
        if (hasStaffRole) {
          alert("User already has an active staff role. Remove it first.");
          return;
        }
        if (!parentStaffId) {
          alert("Select a County Admin parent");
          return;
        }
        if (!confirm("Make this user a BD under the selected County Admin?")) return;
        res = await promoteToBd(userId, parentStaffId);
      } else if (assignRole === "agency_owner") {
        if (ownedAgency) {
          alert(`User already owns agency: ${ownedAgency.name}`);
          return;
        }
        if (!agencyName.trim()) {
          alert("Enter an agency name");
          return;
        }
        if (!confirm(`Create agency "${agencyName.trim()}" and make this user the owner?`)) return;
        res = await createAgencyForOwner(userId, agencyName.trim(), sponsorStaffId || null);
      } else {
        if (!hostAgencyId) {
          alert("Kis agency mein host banaye? Agency select karein.");
          return;
        }
        const agency = agencies.find((a) => a.id === hostAgencyId);
        if (!confirm(`Make this user a host in "${agency?.name ?? "agency"}"?`)) return;
        res = await assignHostToAgency(userId, hostAgencyId);
      }
      if (!res.success) {
        alert(`Error: ${res.error}`);
      } else {
        setParentStaffId("");
        setAgencyName("");
        setSponsorStaffId("");
        setHostAgencyId("");
        router.refresh();
      }
    } finally {
      setLoading(null);
    }
  };
  const handleRemoveStaff = async () => {
    if (!staffId || !confirm(`Remove ${staffRoleLabels[staffRole!] || staffRole} role?`)) return;
    setLoading("role");
    const res = await deactivateStaffRole(staffId, userId);
    if (!res.success) alert(`Error: ${res.error}`);
    else router.refresh();
    setLoading(null);
  };
  const handleRemoveHost = async (agencyId: string, agencyName: string) => {
    if (
      !confirm(
        `Remove host from "${agencyName}"?\n\n• Agency membership will be removed\n• User account / UID stays\n• They can join another agency later`,
      )
    ) {
      return;
    }
    setLoading("role");
    const res = await removeHostFromAgency(userId, agencyId);
    if (!res.success) alert(`Error: ${res.error}`);
    else router.refresh();
    setLoading(null);
  };
  const handleTransferHost = async () => {
    if (!transferToAgencyId) {
      alert("Select destination agency");
      return;
    }
    const current = hostMemberships[0];
    const dest = agencies.find((a) => a.id === transferToAgencyId);
    if (
      !confirm(
        current
          ? `Transfer host from "${current.agencyName}" to "${dest?.name ?? "agency"}"?`
          : `Add host to "${dest?.name ?? "agency"}"?`,
      )
    ) {
      return;
    }
    setLoading("transfer");
    const res = await transferHostToAgency(userId, transferToAgencyId, current?.agencyId ?? null);
    if (!res.success) alert(`Error: ${res.error}`);
    else {
      setTransferToAgencyId("");
      router.refresh();
    }
    setLoading(null);
  };
  return (
    <div className="space-y-6 mt-8">
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        <div className="glass-card flex flex-col gap-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-amber-400">
              <Coins size={20} />
              <span className="text-[10px] font-black uppercase tracking-widest">
                Personal Coins
              </span>
            </div>
            {loading === "coins" && <Loader2 size={16} className="animate-spin text-amber-400" />}
          </div>

          <div className="flex items-end justify-between">
            <h4 className="text-3xl font-black">{coins.toLocaleString()}</h4>
            <span className="text-[10px] text-white/30 font-bold uppercase">Current Balance</span>
          </div>

          <div className="flex flex-col gap-3">
            <input
              type="number"
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-amber-500/50 transition-all"
              placeholder="New amount..."
              id="coin-input"
            />
            <button
              onClick={() => {
                const input = document.getElementById("coin-input") as HTMLInputElement;
                if (input.value) handleUpdate("coins", parseInt(input.value));
              }}
              disabled={loading !== null}
              className="w-full py-3 bg-amber-500 text-black font-black text-xs uppercase tracking-widest rounded-xl hover:bg-amber-400 transition-all disabled:opacity-50 active:scale-95"
            >
              Update Coins
            </button>
          </div>
        </div>

        <div className="glass-card flex flex-col gap-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-blue-400">
              <Diamond size={20} />
              <span className="text-[10px] font-black uppercase tracking-widest">
                Diamonds Management
              </span>
            </div>
            {loading === "diamonds" && <Loader2 size={16} className="animate-spin text-blue-400" />}
          </div>

          <div className="flex items-end justify-between">
            <h4 className="text-3xl font-black">{diamonds.toLocaleString()}</h4>
            <span className="text-[10px] text-white/30 font-bold uppercase">Current Balance</span>
          </div>

          <div className="flex flex-col gap-3">
            <input
              type="number"
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-blue-500/50 transition-all"
              placeholder="New amount..."
              id="diamond-input"
            />
            <button
              onClick={() => {
                const input = document.getElementById("diamond-input") as HTMLInputElement;
                if (input.value) handleUpdate("diamonds", parseInt(input.value));
              }}
              disabled={loading !== null}
              className="w-full py-3 bg-blue-500 text-white font-black text-xs uppercase tracking-widest rounded-xl hover:bg-blue-400 transition-all disabled:opacity-50 active:scale-95"
            >
              Update Diamonds
            </button>
          </div>
        </div>

        <div className="glass-card flex flex-col gap-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-orange-400">
              <BadgeDollarSign size={20} />
              <span className="text-[10px] font-black uppercase tracking-widest">
                Reseller Coins
              </span>
            </div>
            {loading === "reseller_coins" && (
              <Loader2 size={16} className="animate-spin text-orange-400" />
            )}
          </div>

          <div className="flex items-end justify-between">
            <h4 className="text-3xl font-black">{resellerCoins.toLocaleString()}</h4>
            <span className="text-[10px] text-white/30 font-bold uppercase">Stock Balance</span>
          </div>

          <div className="flex flex-col gap-3">
            <input
              type="number"
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-orange-500/50 transition-all"
              placeholder="New amount..."
              id="reseller-coin-input"
            />
            <button
              onClick={() => {
                const input = document.getElementById("reseller-coin-input") as HTMLInputElement;
                if (input.value) handleUpdate("reseller_coins", parseInt(input.value));
              }}
              disabled={loading !== null}
              className="w-full py-3 bg-orange-500 text-black font-black text-xs uppercase tracking-widest rounded-xl hover:bg-orange-400 transition-all disabled:opacity-50 active:scale-95"
            >
              Update Reseller Coins
            </button>
          </div>
        </div>

        <div className="glass-card flex flex-col gap-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-emerald-400">
              <Coins size={20} />
              <span className="text-[10px] font-black uppercase tracking-widest">Cash Balance</span>
            </div>
            {loading === "cash_balance" && (
              <Loader2 size={16} className="animate-spin text-emerald-400" />
            )}
          </div>

          <div className="flex items-end justify-between">
            <h4 className="text-3xl font-black">
              $
              {Number(cashBalance).toLocaleString(undefined, {
                minimumFractionDigits: 0,
                maximumFractionDigits: 2,
              })}
            </h4>
            <span className="text-[10px] text-white/30 font-bold uppercase">USD Wallet</span>
          </div>

          <div className="flex flex-col gap-3">
            <input
              type="number"
              step="0.01"
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-emerald-500/50 transition-all"
              placeholder="New amount..."
              id="cash-balance-input"
            />
            <button
              onClick={() => {
                const input = document.getElementById("cash-balance-input") as HTMLInputElement;
                if (input.value) handleUpdate("cash_balance", parseFloat(input.value));
              }}
              disabled={loading !== null}
              className="w-full py-3 bg-emerald-500 text-black font-black text-xs uppercase tracking-widest rounded-xl hover:bg-emerald-400 transition-all disabled:opacity-50 active:scale-95"
            >
              Update Cash Balance
            </button>
          </div>
        </div>

        <div className="glass-card flex flex-col gap-6 justify-between">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-white/60">
              <ShieldAlert size={20} />
              <span className="text-[10px] font-black uppercase tracking-widest">
                Account Status
              </span>
            </div>
            {loading === "ban" && <Loader2 size={16} className="animate-spin text-white/40" />}
          </div>

          <div className="flex items-center justify-center py-4">
            {isBanned ? (
              <div className="flex flex-col items-center gap-2 px-2">
                <span className="px-4 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-black uppercase tracking-widest">
                  Banned
                </span>
                <p className="text-[10px] text-white/30 font-medium">Access Restricted</p>
                {banReason ? (
                  <p className="mt-2 text-center text-xs text-white/60 leading-relaxed max-w-[240px]">
                    Note: {banReason}
                  </p>
                ) : (
                  <p className="mt-2 text-[10px] text-white/25">No admin note</p>
                )}
              </div>
            ) : (
              <div className="flex flex-col items-center gap-2">
                <span className="px-4 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[10px] font-black uppercase tracking-widest">
                  Active
                </span>
                <p className="text-[10px] text-white/30 font-medium">Standard Account</p>
              </div>
            )}
          </div>

          <button
            onClick={handleBanToggle}
            disabled={loading !== null}
            className={`w-full py-4 rounded-2xl font-black text-xs uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-2 ${
              isBanned
                ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 hover:bg-emerald-500 hover:text-black"
                : "bg-red-500/10 text-red-400 border border-red-400/20 hover:bg-red-500 hover:text-white"
            }`}
          >
            {isBanned ? <ShieldCheck size={18} /> : <ShieldAlert size={18} />}
            {isBanned ? "Unban User" : "Ban User"}
          </button>
        </div>

        <div className="glass-card flex flex-col gap-6 justify-between">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-white/60">
              <Smartphone size={20} />
              <span className="text-[10px] font-black uppercase tracking-widest">
                Device Status
              </span>
            </div>
            {loading === "device_ban" && (
              <Loader2 size={16} className="animate-spin text-white/40" />
            )}
          </div>

          <div className="flex flex-col items-center gap-2 py-2 px-2">
            {deviceBanned ? (
              <>
                <span className="px-4 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-black uppercase tracking-widest">
                  Device Banned
                </span>
                <p className="text-[10px] text-white/30 font-medium text-center">
                  Blocks install UUID + ANDROID_ID + FCM
                </p>
                {deviceBanMatched ? (
                  <p className="text-[9px] text-red-300/50 font-mono text-center">
                    matched: {deviceBanMatched}
                  </p>
                ) : null}
                {deviceBanReason ? (
                  <p className="mt-1 text-center text-xs text-white/60 leading-relaxed max-w-[240px]">
                    Note: {deviceBanReason}
                  </p>
                ) : null}
              </>
            ) : (
              <>
                <span className="px-4 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[10px] font-black uppercase tracking-widest">
                  {hasAnyDeviceSignal ? "Device Active" : "No Device Yet"}
                </span>
                <p className="text-[10px] text-white/30 font-medium text-center">
                  {hasAnyDeviceSignal
                    ? "Ban covers install / ANDROID_ID / FCM when known"
                    : "User must open the app once before device ban"}
                </p>
              </>
            )}
            <div className="mt-2 w-full space-y-1">
              <p className="text-[9px] text-white/25 font-mono break-all text-center">
                install: {lastDeviceId || "—"}
              </p>
              <p className="text-[9px] text-white/25 font-mono break-all text-center">
                android: {lastAndroidId || "—"}
              </p>
              <p className="text-[9px] text-white/25 font-mono text-center">
                fcm: {hasFcmToken ? "present" : "—"}
              </p>
            </div>
          </div>

          <button
            onClick={handleDeviceBanToggle}
            disabled={loading !== null || (!hasAnyDeviceSignal && !deviceBanned)}
            className={`w-full py-4 rounded-2xl font-black text-xs uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-2 ${
              deviceBanned
                ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 hover:bg-emerald-500 hover:text-black"
                : "bg-red-500/10 text-red-400 border border-red-400/20 hover:bg-red-500 hover:text-white"
            } disabled:opacity-40`}
          >
            {deviceBanned ? <ShieldCheck size={18} /> : <Smartphone size={18} />}
            {deviceBanned ? "Unban Device" : "Ban Device"}
          </button>
        </div>

        <div className="glass-card flex flex-col gap-6 justify-between">
          {" "}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-orange-400">
              <BadgeDollarSign size={20} />
              <span className="text-[10px] font-black uppercase tracking-widest">
                Reseller Status
              </span>
            </div>
            {loading === "reseller" && (
              <Loader2 size={16} className="animate-spin text-orange-400" />
            )}
          </div>
          <div className="flex items-center justify-center py-4">
            {isReseller ? (
              <div className="flex flex-col items-center gap-2">
                <span className="px-4 py-1 rounded-full bg-orange-500/10 border border-orange-500/20 text-orange-400 text-[10px] font-black uppercase tracking-widest">
                  Reseller
                </span>
                <p className="text-[10px] text-white/30 font-medium">Authorized to sell coins</p>
              </div>
            ) : (
              <div className="flex flex-col items-center gap-2">
                <span className="px-4 py-1 rounded-full bg-white/5 border border-white/10 text-white/40 text-[10px] font-black uppercase tracking-widest">
                  Standard
                </span>
                <p className="text-[10px] text-white/30 font-medium">Not a reseller</p>
              </div>
            )}
          </div>
          <button
            onClick={handleResellerToggle}
            disabled={loading !== null}
            className={`w-full py-4 rounded-2xl font-black text-xs uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-2 ${
              isReseller
                ? "bg-white/5 text-white/60 border border-white/10 hover:bg-white/10 hover:text-white"
                : "bg-orange-500/10 text-orange-400 border border-orange-400/20 hover:bg-orange-500 hover:text-black"
            }`}
          >
            <BadgeDollarSign size={18} />
            {isReseller ? "Remove Reseller" : "Make Reseller"}
          </button>
        </div>
      </div>

      <div className="glass-card space-y-5">
        <div className="flex items-center gap-2 text-sky-300">
          <Globe2 size={20} className="text-sky-400" />
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest">Country</p>
            <p className="text-xs text-white/40 mt-1">Change the user’s profile country / flag</p>
          </div>
          {loading === "country" && (
            <Loader2 size={16} className="animate-spin text-sky-400 ml-auto" />
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-[1fr_auto] gap-4 items-end">
          <div>
            <p className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] mb-2">
              Country
            </p>
            <div className="flex items-center gap-3">
              <CountryFlag code={countryCode || null} size={28} />
              <select
                value={countryCode}
                onChange={(e) => setCountryCode(e.target.value)}
                className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-sky-500/50"
              >
                <option value="">No country</option>
                {ADMIN_COUNTRY_OPTIONS.map((c) => (
                  <option key={c.code} value={c.code}>
                    {c.name} ({c.code})
                  </option>
                ))}
                {countryCode && !ADMIN_COUNTRY_OPTIONS.some((c) => c.code === countryCode) && (
                  <option value={countryCode}>{countryCode} (current)</option>
                )}
              </select>
            </div>
          </div>
          <button
            type="button"
            disabled={loading !== null}
            onClick={async () => {
              setLoading("country");
              const res = await updateUserCountry(
                userId,
                countryCode.trim() === "" ? null : countryCode,
              );
              if (!res.success) {
                alert(res.error || "Failed");
              } else {
                router.refresh();
              }
              setLoading(null);
            }}
            className="py-3 px-6 bg-sky-500 text-black font-black text-xs uppercase tracking-widest rounded-xl hover:bg-sky-400 transition-all disabled:opacity-50"
          >
            Save Country
          </button>
        </div>
      </div>

      <div className="glass-card space-y-5">
        <div className="flex items-center gap-2 text-fuchsia-300">
          <Sparkles size={20} className="text-fuchsia-400" />
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest">Special ID</p>
            <p className="text-xs text-white/40 mt-1">
              Custom UID + good-number bubble style (SVGA LV1–9)
            </p>
          </div>
          {loading === "special_id" && (
            <Loader2 size={16} className="animate-spin text-fuchsia-400 ml-auto" />
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <p className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] mb-2">
              User ID (short_id)
            </p>
            <input
              type="number"
              value={shortId}
              onChange={(e) => setShortId(e.target.value)}
              placeholder="e.g. 888888"
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-fuchsia-500/50"
            />
          </div>
          <div>
            <p className="text-[9px] font-bold text-white/30 uppercase tracking-[0.2em] mb-2">
              Bubble style
            </p>
            <select
              value={specialLevel}
              onChange={(e) => setSpecialLevel(e.target.value)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-fuchsia-500/50"
            >
              <option value="0">None (plain ID)</option>
              <option value="1">LV1 Bronze</option>
              <option value="2">LV2 Silver</option>
              <option value="3">LV3 Gold</option>
              <option value="4">LV4 Emerald</option>
              <option value="5">LV5 Sapphire</option>
              <option value="6">LV6 Amethyst</option>
              <option value="7">LV7 Rose</option>
              <option value="8">LV8 Ruby</option>
              <option value="9">LV9 Diamond</option>
            </select>
          </div>
          <div className="flex items-end">
            <button
              type="button"
              disabled={loading !== null}
              onClick={async () => {
                setLoading("special_id");
                const levelNum = Number(specialLevel);
                const shortNum = shortId.trim() === "" ? null : Number(shortId);
                if (shortNum != null && (!Number.isFinite(shortNum) || shortNum < 1)) {
                  alert("Invalid short ID");
                  setLoading(null);
                  return;
                }
                const res = await setUserSpecialId(userId, {
                  level: levelNum,
                  shortId: shortNum,
                });
                if (!res.success) {
                  alert(res.error || "Failed");
                } else {
                  router.refresh();
                }
                setLoading(null);
              }}
              className="w-full py-3 bg-fuchsia-500 text-black font-black text-xs uppercase tracking-widest rounded-xl hover:bg-fuchsia-400 transition-all disabled:opacity-50"
            >
              Save Special ID
            </button>
          </div>
        </div>
      </div>

      <div className="glass-card space-y-6">
        <div className="flex items-center justify-between gap-3 flex-wrap">
          <div className="flex items-center gap-2 text-cyan-400">
            <Network size={20} />
            <span className="text-[10px] font-black uppercase tracking-widest">
              Role Management
            </span>
          </div>
          {loading === "role" && <Loader2 size={16} className="animate-spin text-cyan-400" />}
        </div>

        <div className="flex flex-wrap gap-2">
          {hasStaffRole && (
            <span className="px-3 py-1 rounded-full bg-cyan-500/10 border border-cyan-500/20 text-cyan-300 text-[10px] font-black uppercase tracking-widest">
              {staffRoleLabels[staffRole!] || staffRole}
              {staffCode ? ` · ${staffCode}` : ""}
            </span>
          )}
          {ownedAgency && (
            <span className="px-3 py-1 rounded-full bg-violet-500/10 border border-violet-500/20 text-violet-300 text-[10px] font-black uppercase tracking-widest">
              Agency Owner · {ownedAgency.name}
              {ownedAgency.agencyCode ? ` (${ownedAgency.agencyCode})` : ""}
            </span>
          )}
          {hostMemberships.map((h) => (
            <span
              key={h.agencyId}
              className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-[10px] font-black uppercase tracking-widest"
            >
              Host · {h.agencyName}
              <button
                type="button"
                disabled={loading !== null}
                onClick={() => handleRemoveHost(h.agencyId, h.agencyName)}
                className="text-emerald-200/70 hover:text-white underline-offset-2 hover:underline"
              >
                remove
              </button>
            </span>
          ))}
          {!hasStaffRole && !ownedAgency && hostMemberships.length === 0 && (
            <span className="px-3 py-1 rounded-full bg-white/5 border border-white/10 text-white/40 text-[10px] font-black uppercase tracking-widest">
              No business roles
            </span>
          )}
        </div>

        {hasStaffRole && staffId && (
          <div className="flex flex-wrap items-center gap-3">
            <Link
              href={`/staff/${staffId}`}
              className="text-[10px] font-bold uppercase tracking-widest text-cyan-400/80 hover:text-cyan-300"
            >
              View staff profile
            </Link>
            <button
              type="button"
              onClick={handleRemoveStaff}
              disabled={loading !== null}
              className="px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest bg-white/5 text-white/60 border border-white/10 hover:bg-white/10 hover:text-white disabled:opacity-50"
            >
              Remove staff role
            </button>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <label className="block space-y-1.5">
            <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
              Assign role
            </span>
            <select
              value={assignRole}
              onChange={(e) => {
                setAssignRole(e.target.value as AssignRole);
                setParentStaffId("");
                setHostAgencyId("");
              }}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-cyan-500/50"
            >
              <option value="super_bd">Super Admin</option>
              <option value="bd_admin">County Admin</option>
              <option value="bd">BD</option>
              <option value="agency_owner">Agency Owner</option>
              <option value="host">Host</option>
            </select>
          </label>

          {(assignRole === "bd_admin" || assignRole === "bd") && (
            <label className="block space-y-1.5">
              <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
                {assignRole === "bd_admin" ? "Parent Super Admin" : "Parent County Admin"}
              </span>
              <select
                value={parentStaffId}
                onChange={(e) => setParentStaffId(e.target.value)}
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-cyan-500/50"
              >
                <option value="">Select parent…</option>
                {parentOptions.map((opt) => (
                  <option key={opt.id} value={opt.id}>
                    {staffLabel(opt)}
                  </option>
                ))}
              </select>
            </label>
          )}

          {assignRole === "agency_owner" && (
            <>
              <label className="block space-y-1.5">
                <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
                  Agency name
                </span>
                <input
                  value={agencyName}
                  onChange={(e) => setAgencyName(e.target.value)}
                  placeholder="e.g. Star Agency"
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-cyan-500/50"
                />
              </label>
              <label className="block space-y-1.5">
                <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
                  Sponsor BD (optional)
                </span>
                <select
                  value={sponsorStaffId}
                  onChange={(e) => setSponsorStaffId(e.target.value)}
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-cyan-500/50"
                >
                  <option value="">None</option>
                  {bdOptions.map((opt) => (
                    <option key={opt.id} value={opt.id}>
                      {staffLabel(opt)}
                    </option>
                  ))}
                </select>
              </label>
            </>
          )}

          {assignRole === "host" && (
            <label className="block space-y-1.5 lg:col-span-1">
              <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
                Kis agency mein host banaye?
              </span>
              <select
                value={hostAgencyId}
                onChange={(e) => setHostAgencyId(e.target.value)}
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-cyan-500/50"
              >
                <option value="">Select agency…</option>
                {agencies.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.name}
                    {a.agencyCode ? ` (${a.agencyCode})` : ""}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>

        <button
          type="button"
          onClick={handleAssignRole}
          disabled={loading !== null}
          className="w-full md:w-auto px-8 py-4 rounded-2xl font-black text-xs uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-2 bg-cyan-500/10 text-cyan-300 border border-cyan-400/20 hover:bg-cyan-500 hover:text-black disabled:opacity-50"
        >
          <Network size={18} />
          Assign Role
        </button>
      </div>

      <div className="glass-card space-y-5">
        <div className="flex items-center justify-between gap-3 flex-wrap">
          <div className="flex items-center gap-2 text-emerald-400">
            <ArrowLeftRight size={20} />
            <span className="text-[10px] font-black uppercase tracking-widest">
              Transfer Host Agency
            </span>
          </div>
          {loading === "transfer" && (
            <Loader2 size={16} className="animate-spin text-emerald-400" />
          )}
        </div>

        <p className="text-sm text-white/45">
          Move this user from their current agency into any other agency.
          {hostMemberships[0]
            ? ` Currently in: ${hostMemberships[0].agencyName}.`
            : " Currently not in any agency — this will add them as a host."}
        </p>

        <div className="grid grid-cols-1 md:grid-cols-[1fr_auto] gap-4 items-end">
          <label className="block space-y-1.5">
            <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
              Destination agency
            </span>
            <select
              value={transferToAgencyId}
              onChange={(e) => setTransferToAgencyId(e.target.value)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-emerald-500/50"
            >
              <option value="">Select agency…</option>
              {agencies
                .filter((a) => a.id !== hostMemberships[0]?.agencyId)
                .map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.name}
                    {a.agencyCode ? ` (${a.agencyCode})` : ""}
                  </option>
                ))}
            </select>
          </label>
          <button
            type="button"
            onClick={handleTransferHost}
            disabled={loading !== null || !transferToAgencyId}
            className="px-8 py-4 rounded-2xl font-black text-xs uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-2 bg-emerald-500/10 text-emerald-300 border border-emerald-400/20 hover:bg-emerald-500 hover:text-black disabled:opacity-50"
          >
            <ArrowLeftRight size={18} />
            Transfer
          </button>
        </div>
      </div>

      {showBanModal && (
        <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/70 p-4">
          <div className="w-full max-w-md rounded-2xl border border-white/10 bg-[#12141a] p-6 shadow-2xl space-y-4">
            <div>
              <h3 className="text-lg font-black text-white">Ban User</h3>
              <p className="mt-1 text-sm text-white/50">
                Saves to Supabase immediately. Optional note is shown full-screen in the app.
              </p>
            </div>
            <textarea
              value={banNoteDraft}
              onChange={(e) => setBanNoteDraft(e.target.value)}
              rows={4}
              maxLength={500}
              placeholder="Admin note (optional) — e.g. reason for ban"
              className="w-full rounded-xl bg-white/5 border border-white/10 px-3 py-3 text-sm text-white placeholder:text-white/30 focus:outline-none focus:border-red-400/40"
            />
            <div className="flex gap-2">
              <button
                type="button"
                disabled={loading !== null}
                onClick={() => {
                  setShowBanModal(false);
                  setBanNoteDraft("");
                }}
                className="flex-1 rounded-xl border border-white/10 bg-white/5 py-3 text-xs font-black uppercase tracking-widest text-white/70 hover:bg-white/10"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={loading !== null}
                onClick={() => applyBanToggle(banNoteDraft)}
                className="flex-1 rounded-xl bg-red-500 py-3 text-xs font-black uppercase tracking-widest text-white hover:bg-red-400 disabled:opacity-50"
              >
                {loading === "ban" ? "Banning…" : "Confirm Ban"}
              </button>
            </div>
          </div>
        </div>
      )}

      {showDeviceBanModal && (
        <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/70 p-4">
          <div className="w-full max-w-md rounded-2xl border border-white/10 bg-[#12141a] p-6 shadow-2xl space-y-4">
            <div>
              <h3 className="text-lg font-black text-white">Ban Device</h3>
              <p className="mt-1 text-sm text-white/50">
                Locks this phone install. Any account opened on it will see Device Suspended.
              </p>
            </div>
            <textarea
              value={deviceNoteDraft}
              onChange={(e) => setDeviceNoteDraft(e.target.value)}
              rows={4}
              maxLength={500}
              placeholder="Admin note (optional)"
              className="w-full rounded-xl bg-white/5 border border-white/10 px-3 py-3 text-sm text-white placeholder:text-white/30 focus:outline-none focus:border-red-400/40"
            />
            <div className="flex gap-2">
              <button
                type="button"
                disabled={loading !== null}
                onClick={() => {
                  setShowDeviceBanModal(false);
                  setDeviceNoteDraft("");
                }}
                className="flex-1 rounded-xl border border-white/10 bg-white/5 py-3 text-xs font-black uppercase tracking-widest text-white/70 hover:bg-white/10"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={loading !== null}
                onClick={() => applyDeviceBan(deviceNoteDraft)}
                className="flex-1 rounded-xl bg-red-500 py-3 text-xs font-black uppercase tracking-widest text-white hover:bg-red-400 disabled:opacity-50"
              >
                {loading === "device_ban" ? "Banning…" : "Confirm Device Ban"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
