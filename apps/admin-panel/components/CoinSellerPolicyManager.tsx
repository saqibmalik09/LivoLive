"use client";
import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Coins, Loader2, Plus, Search, Trash2, Save, CheckCircle2 } from "lucide-react";
import { toast } from "sonner";
import { ShopItemPickerModal, type ShopPickerItem } from "@/components/ShopItemPickerModal";
import {
  clearCoinSellerReward,
  deleteCoinSellerTier,
  fulfillCoinSellerPurchase,
  saveCoinSellerReward,
  searchUsersForSellerFulfill,
  toggleCoinSellerTier,
  updateCoinSellerSettings,
  upsertCoinSellerTier,
} from "@/app/settings/coin-seller-policy/actions";
export type SellerTier = {
  id: string;
  usd_amount: number | string;
  basic_coins: number | string;
  bonus_ratio_percent: number | string;
  total_coins: number | string;
  label: string | null;
  is_active: boolean;
  sort_order: number;
};
export type SellerReward = {
  id: string;
  tier_id: string;
  feature_key: string;
  vip_plan_id: string | null;
  shop_item_id: string | null;
  duration_days: number | null;
  label: string | null;
  sort_order: number;
  shop_item_name?: string | null;
  shop_item_image?: string | null;
};
export type VipPlanOption = {
  id: string;
  level: number;
  name: string;
  duration_days: number | null;
};
export type SellerPurchase = {
  id: string;
  usd_amount: number | string;
  coins_credited: number | string;
  notes: string | null;
  created_at: string;
  username: string | null;
  short_id: number | null;
};
const FEATURES = [
  { key: "vip", label: "VIP", picker: null as string | null },
  { key: "frame", label: "Frame", picker: "frame" },
  { key: "entrance", label: "Entrance", picker: "entrance" },
  { key: "custom", label: "Custom item", picker: "custom" },
] as const;
function fmt(n: number | string | bigint) {
  if (typeof n === "bigint") return n.toLocaleString();
  return Number(n).toLocaleString();
}
export function CoinSellerPolicyManager({
  settings,
  tiers,
  rewards,
  vipPlans,
  purchases,
}: {
  settings: {
    coins_per_usd: number | string;
    min_recharge_usd: number | string;
    is_active: boolean;
  } | null;
  tiers: SellerTier[];
  rewards: SellerReward[];
  vipPlans: VipPlanOption[];
  purchases: SellerPurchase[];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState<string | null>(null);
  const [picker, setPicker] = useState<{
    tierId: string;
    featureKey: string;
  } | null>(null);
  const [usd, setUsd] = useState("500");
  const [basic, setBasic] = useState("44000000");
  const [ratio, setRatio] = useState("127");
  const [totalOverride, setTotalOverride] = useState("");
  const [search, setSearch] = useState("");
  const [userHits, setUserHits] = useState<any[]>([]);
  const [selectedUser, setSelectedUser] = useState<any | null>(null);
  const [selectedTierId, setSelectedTierId] = useState("");
  const [fulfillCoins, setFulfillCoins] = useState("");
  const [fulfillUsd, setFulfillUsd] = useState("");
  const [notes, setNotes] = useState("");
  const activeTiers = useMemo(() => tiers.filter((t) => t.is_active), [tiers]);
  const selectedTier = useMemo(
    () => activeTiers.find((t) => t.id === selectedTierId) ?? null,
    [activeTiers, selectedTierId],
  );
  function applyTierDefaults(tierId: string) {
    setSelectedTierId(tierId);
    if (!tierId) return;
    const t = tiers.find((x) => x.id === tierId);
    if (!t) return;
    setFulfillCoins(String(Number(t.total_coins)));
    setFulfillUsd(String(Number(t.usd_amount)));
  }
  function parseFreeCoins(raw: string): bigint | null {
    const cleaned = raw.trim().replace(/,/g, "").replace(/\s/g, "");
    if (!cleaned || cleaned === "-" || cleaned === "+") return null;
    if (!/^[+-]?\d+$/.test(cleaned)) return null;
    try {
      const n = BigInt(cleaned);
      if (n === BigInt(0)) return null;
      return n;
    } catch {
      return null;
    }
  }
  function parseFreeUsd(raw: string): number | null {
    const cleaned = raw.trim().replace(/,/g, "");
    if (!cleaned) return 0;
    const n = Number(cleaned);
    if (!Number.isFinite(n)) return null;
    return n;
  }
  const computedTotal = useMemo(() => {
    const b = Number(basic);
    const r = Number(ratio);
    if (!Number.isFinite(b) || !Number.isFinite(r)) return 0;
    return Math.round(b * (r / 100));
  }, [basic, ratio]);
  function refresh() {
    router.refresh();
  }
  async function saveSettings(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy("settings");
    try {
      const fd = new FormData(e.currentTarget);
      await updateCoinSellerSettings(fd);
      toast.success("Settings saved");
      refresh();
    } catch (err: any) {
      toast.error(err?.message ?? "Save failed");
    } finally {
      setBusy(null);
    }
  }
  async function addTier() {
    setBusy("add-tier");
    try {
      await upsertCoinSellerTier({
        usd_amount: Number(usd),
        basic_coins: Number(basic),
        bonus_ratio_percent: Number(ratio),
        total_coins: totalOverride ? Number(totalOverride) : computedTotal,
        label: `$${usd}`,
        is_active: true,
        sort_order: tiers.length + 1,
      });
      toast.success("Tier added");
      setTotalOverride("");
      refresh();
    } catch (err: any) {
      toast.error(err?.message ?? "Failed");
    } finally {
      setBusy(null);
    }
  }
  async function saveTierRow(tier: SellerTier, form: HTMLFormElement) {
    const fd = new FormData(form);
    setBusy(tier.id);
    try {
      await upsertCoinSellerTier({
        id: tier.id,
        usd_amount: Number(fd.get("usd_amount")),
        basic_coins: Number(fd.get("basic_coins")),
        bonus_ratio_percent: Number(fd.get("bonus_ratio_percent")),
        total_coins: Number(fd.get("total_coins")),
        label: String(fd.get("label") || ""),
        is_active: tier.is_active,
        sort_order: Number(fd.get("sort_order") || tier.sort_order),
      });
      toast.success("Tier updated");
      refresh();
    } catch (err: any) {
      toast.error(err?.message ?? "Update failed");
    } finally {
      setBusy(null);
    }
  }
  async function onPickShop(item: ShopPickerItem) {
    if (!picker) return;
    const key = `${picker.tierId}:${picker.featureKey}`;
    setBusy(key);
    try {
      await saveCoinSellerReward({
        tier_id: picker.tierId,
        feature_key: picker.featureKey,
        shop_item_id: item.id,
        vip_plan_id: null,
        label: item.name,
        duration_days: 30,
      });
      toast.success("Reward saved");
      setPicker(null);
      refresh();
    } catch (err: any) {
      toast.error(err?.message ?? "Save failed");
    } finally {
      setBusy(null);
    }
  }
  async function onVipSelect(tierId: string, planId: string) {
    const plan = vipPlans.find((p) => p.id === planId);
    setBusy(`${tierId}:vip`);
    try {
      if (!planId) {
        await clearCoinSellerReward(tierId, "vip");
      } else {
        await saveCoinSellerReward({
          tier_id: tierId,
          feature_key: "vip",
          vip_plan_id: planId,
          shop_item_id: null,
          label: plan?.name ?? "VIP",
          duration_days: plan?.duration_days ?? 30,
        });
      }
      toast.success("VIP reward updated");
      refresh();
    } catch (err: any) {
      toast.error(err?.message ?? "Failed");
    } finally {
      setBusy(null);
    }
  }
  async function onDuration(tierId: string, featureKey: string, days: number) {
    const existing = rewards.find((r) => r.tier_id === tierId && r.feature_key === featureKey);
    if (!existing) return;
    setBusy(`${tierId}:${featureKey}:dur`);
    try {
      await saveCoinSellerReward({
        tier_id: tierId,
        feature_key: featureKey,
        vip_plan_id: existing.vip_plan_id,
        shop_item_id: existing.shop_item_id,
        label: existing.label,
        duration_days: days,
      });
      toast.success("Duration saved");
      refresh();
    } catch (err: any) {
      toast.error(err?.message ?? "Failed");
    } finally {
      setBusy(null);
    }
  }
  async function runSearch() {
    setBusy("search");
    try {
      const hits = await searchUsersForSellerFulfill(search);
      setUserHits(hits);
      if (hits.length === 0) toast.message("No users found");
    } catch (err: any) {
      toast.error(err?.message ?? "Search failed");
    } finally {
      setBusy(null);
    }
  }
  async function fulfill() {
    if (!selectedUser) {
      toast.error("Select a user");
      return;
    }
    const coins = parseFreeCoins(fulfillCoins);
    if (coins == null) {
      toast.error("Type any non-zero coin amount (negative to deduct). No tier required.");
      return;
    }
    const usd = parseFreeUsd(fulfillUsd);
    if (usd == null) {
      toast.error("USD must be a number (leave blank for 0)");
      return;
    }
    const coinsLabel = coins < BigInt(0) ? `−${fmt(coins * BigInt(-1))}` : fmt(coins);
    const label = selectedTier
      ? `optional tier $${Number(selectedTier.usd_amount)} rewards + ${coinsLabel} coins / $${usd}`
      : `custom ${coinsLabel} coins / $${usd} (no tier rewards)`;
    if (
      !confirm(
        `${coins < BigInt(0) ? "Deduct" : "Credit"} ${coinsLabel} reseller coins for ${selectedUser.username} (ID ${selectedUser.short_id})?\n\n${label}`,
      )
    ) {
      return;
    }
    setBusy("fulfill");
    try {
      const res: any = await fulfillCoinSellerPurchase({
        user_id: selectedUser.id,
        tier_id: selectedTierId || null,
        notes: notes || null,
        coins_override: coins.toString(),
        usd_override: usd,
      });
      if (res?.success === false) throw new Error(res.message || "Fulfill failed");
      const credited = BigInt(String(res?.coins_credited ?? coins.toString()));
      toast.success(
        credited < BigInt(0)
          ? `Deducted ${fmt(credited * BigInt(-1))} reseller coins`
          : `Credited ${fmt(credited)} reseller coins`,
      );
      setNotes("");
      setFulfillCoins("");
      setFulfillUsd("");
      setSelectedTierId("");
      refresh();
    } catch (err: any) {
      toast.error(err?.message ?? "Fulfill failed");
    } finally {
      setBusy(null);
    }
  }
  return (
    <div className="space-y-10">
      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-4">
        <h2 className="text-xl font-bold">Global settings</h2>
        <form onSubmit={saveSettings} className="flex flex-wrap items-end gap-4">
          <label className="text-sm text-white/60">
            Coins per USD
            <input
              name="coins_per_usd"
              type="number"
              defaultValue={Number(settings?.coins_per_usd ?? 88000)}
              className="mt-1 block w-40 rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <label className="text-sm text-white/60">
            Min recharge USD
            <input
              name="min_recharge_usd"
              type="number"
              step="0.01"
              defaultValue={Number(settings?.min_recharge_usd ?? 500)}
              className="mt-1 block w-40 rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <label className="flex items-center gap-2 text-sm text-white/60 pb-2">
            <input
              name="is_active"
              type="checkbox"
              defaultChecked={settings?.is_active ?? true}
              className="rounded"
            />
            Policy active
          </label>
          <button
            type="submit"
            disabled={busy === "settings"}
            className="rounded-xl bg-amber-400 px-4 py-2 font-bold text-sm text-black inline-flex items-center gap-2"
          >
            {busy === "settings" ? (
              <Loader2 className="animate-spin" size={16} />
            ) : (
              <Save size={16} />
            )}
            Save
          </button>
        </form>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-4">
        <h2 className="text-xl font-bold">Add tier</h2>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <label className="text-xs text-white/50">
            USD
            <input
              value={usd}
              onChange={(e) => setUsd(e.target.value)}
              className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <label className="text-xs text-white/50">
            Basic coins
            <input
              value={basic}
              onChange={(e) => setBasic(e.target.value)}
              className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <label className="text-xs text-white/50">
            Ratio %
            <input
              value={ratio}
              onChange={(e) => setRatio(e.target.value)}
              className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <label className="text-xs text-white/50">
            Total coins (optional)
            <input
              value={totalOverride}
              onChange={(e) => setTotalOverride(e.target.value)}
              placeholder={String(computedTotal)}
              className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <button
            type="button"
            onClick={addTier}
            disabled={busy === "add-tier"}
            className="self-end rounded-xl bg-amber-400 px-4 py-2 font-bold text-sm text-black inline-flex items-center justify-center gap-2"
          >
            {busy === "add-tier" ? (
              <Loader2 className="animate-spin" size={16} />
            ) : (
              <Plus size={16} />
            )}
            Add
          </button>
        </div>
        <p className="text-xs text-white/40">Computed total: {fmt(computedTotal)}</p>
      </section>

      <section className="space-y-6">
        <h2 className="text-xl font-bold">Tiers & rewards</h2>
        {tiers.map((tier) => {
          const tierRewards = rewards.filter((r) => r.tier_id === tier.id);
          return (
            <div
              key={tier.id}
              className={`rounded-3xl border border-white/10 bg-black/30 p-5 space-y-5 ${!tier.is_active ? "opacity-60" : ""}`}
            >
              <form
                className="grid grid-cols-2 md:grid-cols-6 gap-3 items-end"
                onSubmit={(e) => {
                  e.preventDefault();
                  saveTierRow(tier, e.currentTarget);
                }}
              >
                <label className="text-xs text-white/50">
                  Label
                  <input
                    name="label"
                    defaultValue={tier.label ?? ""}
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
                  />
                </label>
                <label className="text-xs text-white/50">
                  USD
                  <input
                    name="usd_amount"
                    type="number"
                    step="0.01"
                    defaultValue={Number(tier.usd_amount)}
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
                  />
                </label>
                <label className="text-xs text-white/50">
                  Basic
                  <input
                    name="basic_coins"
                    type="number"
                    defaultValue={Number(tier.basic_coins)}
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
                  />
                </label>
                <label className="text-xs text-white/50">
                  Ratio %
                  <input
                    name="bonus_ratio_percent"
                    type="number"
                    step="0.01"
                    defaultValue={Number(tier.bonus_ratio_percent)}
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
                  />
                </label>
                <label className="text-xs text-white/50">
                  Total coins
                  <input
                    name="total_coins"
                    type="number"
                    defaultValue={Number(tier.total_coins)}
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
                  />
                </label>
                <input type="hidden" name="sort_order" value={tier.sort_order} />
                <div className="flex gap-2">
                  <button
                    type="submit"
                    disabled={busy === tier.id}
                    className="rounded-xl bg-white/10 px-3 py-2 text-sm font-bold inline-flex items-center gap-1"
                  >
                    {busy === tier.id ? (
                      <Loader2 className="animate-spin" size={14} />
                    ) : (
                      <Save size={14} />
                    )}
                    Save
                  </button>
                  <button
                    type="button"
                    className="rounded-xl bg-white/5 px-3 py-2 text-xs"
                    onClick={async () => {
                      await toggleCoinSellerTier(tier.id, !tier.is_active);
                      toast.success(tier.is_active ? "Disabled" : "Enabled");
                      refresh();
                    }}
                  >
                    {tier.is_active ? "Disable" : "Enable"}
                  </button>
                  <button
                    type="button"
                    className="rounded-xl bg-red-500/10 text-red-300 px-3 py-2"
                    onClick={async () => {
                      if (!confirm("Delete this tier?")) return;
                      await deleteCoinSellerTier(tier.id);
                      toast.success("Deleted");
                      refresh();
                    }}
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </form>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
                {FEATURES.map((feat) => {
                  const slot = tierRewards.find((r) => r.feature_key === feat.key);
                  const busyKey = `${tier.id}:${feat.key}`;
                  return (
                    <div
                      key={feat.key}
                      className="rounded-2xl border border-white/10 bg-white/5 p-3 space-y-2"
                    >
                      <div className="text-xs font-bold uppercase tracking-widest text-amber-400/80">
                        {feat.label}
                      </div>
                      {feat.key === "vip" ? (
                        <select
                          className="w-full rounded-lg bg-black/40 border border-white/10 px-2 py-2 text-sm"
                          value={slot?.vip_plan_id ?? ""}
                          onChange={(e) => onVipSelect(tier.id, e.target.value)}
                          disabled={busy === busyKey}
                        >
                          <option value="">None</option>
                          {vipPlans.map((p) => (
                            <option key={p.id} value={p.id}>
                              LV{p.level} — {p.name}
                            </option>
                          ))}
                        </select>
                      ) : (
                        <button
                          type="button"
                          onClick={() => setPicker({ tierId: tier.id, featureKey: feat.key })}
                          className="w-full rounded-lg bg-black/40 border border-white/10 px-2 py-2 text-left text-sm hover:border-amber-400/40"
                        >
                          {slot?.shop_item_name || slot?.label || "Pick shop item…"}
                        </button>
                      )}
                      {(slot?.shop_item_id || slot?.vip_plan_id) && (
                        <div className="flex items-center gap-2">
                          <input
                            type="number"
                            min={1}
                            defaultValue={slot.duration_days ?? 30}
                            className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1 text-sm"
                            onBlur={(e) => {
                              const days = Number(e.target.value);
                              if (days > 0) onDuration(tier.id, feat.key, days);
                            }}
                          />
                          <span className="text-[10px] text-white/40 uppercase">days</span>
                          <button
                            type="button"
                            className="ml-auto text-[10px] text-red-300/80"
                            onClick={async () => {
                              await clearCoinSellerReward(tier.id, feat.key);
                              toast.success("Cleared");
                              refresh();
                            }}
                          >
                            Clear
                          </button>
                        </div>
                      )}
                      {busy === busyKey && (
                        <Loader2 className="animate-spin text-white/40" size={14} />
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </section>

      <section className="rounded-3xl border border-amber-500/20 bg-amber-500/5 p-6 space-y-4">
        <div>
          <h2 className="text-xl font-bold flex items-center gap-2">
            <CheckCircle2 className="text-amber-400" size={22} />
            Fulfill seller purchase
          </h2>
          <p className="text-sm text-white/50 mt-1">
            Type any coins / USD amount and send — no tier required, no amount limit. Negative coins
            deduct stock. Optional tier only adds package rewards (VIP/frame/etc).
          </p>
        </div>

        <div className="flex flex-wrap gap-2">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search username or UID…"
            className="rounded-xl bg-black/40 border border-white/10 px-3 py-2 min-w-[220px]"
            onKeyDown={(e) => e.key === "Enter" && runSearch()}
          />
          <button
            type="button"
            onClick={runSearch}
            className="rounded-xl bg-white/10 px-4 py-2 font-bold text-sm inline-flex items-center gap-2"
          >
            {busy === "search" ? (
              <Loader2 className="animate-spin" size={16} />
            ) : (
              <Search size={16} />
            )}
            Search
          </button>
        </div>

        {userHits.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {userHits.map((u) => (
              <button
                key={u.id}
                type="button"
                onClick={() => setSelectedUser(u)}
                className={`rounded-xl border px-3 py-2 text-sm ${
                  selectedUser?.id === u.id
                    ? "border-amber-400 bg-amber-400/10"
                    : "border-white/10 bg-black/30"
                }`}
              >
                {u.username} · ID {u.short_id}
                {u.is_reseller ? " · reseller" : ""}
                {u.reseller_coins != null ? ` · stock ${fmt(u.reseller_coins)}` : ""}
              </button>
            ))}
          </div>
        )}

        <div className="flex flex-wrap items-end gap-3">
          <label className="text-sm text-white/60">
            Coins (required — any amount)
            <input
              type="text"
              inputMode="numeric"
              autoComplete="off"
              value={fulfillCoins}
              onChange={(e) => setFulfillCoins(e.target.value)}
              placeholder="e.g. 1000000 or -50000"
              className="mt-1 block w-56 rounded-xl bg-black/40 border border-amber-400/40 px-3 py-2 font-mono text-amber-100"
            />
          </label>
          <label className="text-sm text-white/60">
            USD (optional)
            <input
              type="text"
              inputMode="decimal"
              autoComplete="off"
              value={fulfillUsd}
              onChange={(e) => setFulfillUsd(e.target.value)}
              placeholder="0"
              className="mt-1 block w-32 rounded-xl bg-black/40 border border-white/10 px-3 py-2 font-mono"
            />
          </label>
          <label className="text-sm text-white/60">
            Optional tier rewards
            <select
              value={selectedTierId}
              onChange={(e) => applyTierDefaults(e.target.value)}
              className="mt-1 block rounded-xl bg-black/40 border border-white/10 px-3 py-2 min-w-[220px]"
            >
              <option value="">None — coins only</option>
              {activeTiers.map((t) => (
                <option key={t.id} value={t.id}>
                  ${Number(t.usd_amount)} package rewards ({fmt(t.total_coins)} coins prefills)
                </option>
              ))}
            </select>
          </label>
          <label className="text-sm text-white/60 flex-1 min-w-[200px]">
            Notes
            <input
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Payment ref / staff note"
              className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <button
            type="button"
            onClick={fulfill}
            disabled={busy === "fulfill" || !selectedUser}
            className="rounded-xl bg-amber-400 px-5 py-2 font-black text-black inline-flex items-center gap-2 disabled:opacity-40"
          >
            {busy === "fulfill" ? (
              <Loader2 className="animate-spin" size={16} />
            ) : (
              <Coins size={16} />
            )}
            Fulfill
          </button>
        </div>
        <p className="text-xs text-white/35">
          {selectedTier
            ? "Tier selected → VIP/frame rewards still granted. Coins/USD fields always win over package amounts."
            : "No tier → coins credit/deduct only (no VIP/frame rewards)."}
          {selectedUser?.reseller_coins != null
            ? ` Current stock: ${fmt(selectedUser.reseller_coins)}.`
            : ""}
        </p>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-3">
        <h2 className="text-xl font-bold">Recent fulfillments</h2>
        {purchases.length === 0 && <p className="text-sm text-white/40">None yet.</p>}
        <div className="space-y-2">
          {purchases.map((p) => (
            <div
              key={p.id}
              className="flex flex-wrap justify-between gap-2 rounded-xl border border-white/5 bg-black/30 px-4 py-3 text-sm"
            >
              <span>
                {p.username ?? "User"} · ID {p.short_id ?? "—"}
              </span>
              <span className="text-amber-300">
                ${Number(p.usd_amount)} →{" "}
                {Number(p.coins_credited) < 0
                  ? `−${fmt(Math.abs(Number(p.coins_credited)))}`
                  : fmt(p.coins_credited)}{" "}
                coins
              </span>
              <span className="text-white/40">{new Date(p.created_at).toLocaleString()}</span>
            </div>
          ))}
        </div>
      </section>

      <ShopItemPickerModal
        open={!!picker}
        featureKey={picker?.featureKey === "custom" ? "frame" : picker?.featureKey || "frame"}
        title={`Pick ${picker?.featureKey ?? "item"}`}
        onClose={() => setPicker(null)}
        onSelect={onPickShop}
      />
    </div>
  );
}
