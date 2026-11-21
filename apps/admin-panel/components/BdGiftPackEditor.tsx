"use client";
import { CdnImg } from "@/components/CdnImg";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Image as ImageIcon, Loader2, Search } from "lucide-react";
import { toast } from "sonner";
import { uploadFile } from "@/app/shop/actions";
import { ShopItemPickerModal, type ShopPickerItem } from "@/components/ShopItemPickerModal";
import { saveBdGiftPackSlot, saveBdLevelBadgeUrl } from "@/app/settings/bd-center/actions";
export type BdGiftSlot = {
  level: number;
  feature_key: string;
  label: string | null;
  duration_days: number;
  shop_item_id: string | null;
  image_url: string | null;
  shop_item_name?: string | null;
  shop_item_image?: string | null;
};
export type BdLevelBadge = {
  level: number;
  badge_url: string | null;
};
const FEATURE_LABELS: Record<string, string> = {
  bd_frame: "Frame",
  svip: "SVIP / VIP",
  country_bd_badge: "Country BD Badge",
  custom: "Custom",
};
export function BdGiftPackEditor({
  levels,
  slots,
}: {
  levels: BdLevelBadge[];
  slots: BdGiftSlot[];
}) {
  const router = useRouter();
  const [picker, setPicker] = useState<{
    level: number;
    featureKey: string;
  } | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  function refresh() {
    router.refresh();
  }
  async function onPickShop(item: ShopPickerItem) {
    if (!picker) return;
    const key = `${picker.level}:${picker.featureKey}`;
    setBusy(key);
    try {
      await saveBdGiftPackSlot({
        level: picker.level,
        feature_key: picker.featureKey,
        shop_item_id: item.id,
        image_url: item.image_url,
        label: item.name,
      });
      toast.success(
        `LV${picker.level} ${FEATURE_LABELS[picker.featureKey] ?? picker.featureKey} saved`,
      );
      setPicker(null);
      refresh();
    } catch (e: any) {
      toast.error(e?.message ?? "Save failed");
    } finally {
      setBusy(null);
    }
  }
  async function onUploadReward(level: number, featureKey: string, file: File) {
    const key = `${level}:${featureKey}`;
    setBusy(key);
    try {
      const fd = new FormData();
      fd.set("file", file);
      const res = await uploadFile(fd);
      if (!res?.url) throw new Error("Upload failed");
      await saveBdGiftPackSlot({
        level,
        feature_key: featureKey,
        shop_item_id: null,
        image_url: res.url,
        label: file.name.replace(/\.[^.]+$/, ""),
      });
      toast.success(`Uploaded for LV${level}`);
      refresh();
    } catch (e: any) {
      toast.error(e?.message ?? "Upload failed");
    } finally {
      setBusy(null);
    }
  }
  async function onUploadBadge(level: number, file: File) {
    const key = `badge:${level}`;
    setBusy(key);
    try {
      const fd = new FormData();
      fd.set("file", file);
      const res = await uploadFile(fd);
      if (!res?.url) throw new Error("Upload failed");
      await saveBdLevelBadgeUrl(level, res.url);
      toast.success(`Badge LV${level} updated`);
      refresh();
    } catch (e: any) {
      toast.error(e?.message ?? "Badge upload failed");
    } finally {
      setBusy(null);
    }
  }
  async function onDuration(level: number, featureKey: string, days: number) {
    const slot = slots.find((s) => s.level === level && s.feature_key === featureKey);
    await saveBdGiftPackSlot({
      level,
      feature_key: featureKey,
      shop_item_id: slot?.shop_item_id ?? null,
      image_url: slot?.image_url ?? null,
      label: slot?.label ?? null,
      duration_days: days,
    });
    toast.success("Duration saved");
    refresh();
  }
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold">BD Gift Pack (all levels)</h2>
        <p className="text-sm text-white/50 mt-1">
          Assign existing shop items (frame / VIP / badge) or upload custom images. Duration
          defaults to 30 days.
        </p>
      </div>

      {levels.map((lv) => {
        const levelSlots = slots.filter((s) => s.level === lv.level);
        return (
          <div
            key={lv.level}
            className="rounded-2xl border border-white/10 bg-black/30 p-4 space-y-4"
          >
            <div className="flex flex-wrap items-center gap-4">
              <div className="flex items-center gap-3">
                {lv.badge_url ? (
                  <CdnImg
                    src={lv.badge_url}
                    alt={`LV${lv.level}`}
                    className="w-14 h-14 object-contain"
                  />
                ) : (
                  <div className="w-14 h-14 rounded-full bg-violet-500/20 border border-violet-400/40 flex items-center justify-center text-xs font-black">
                    LV{lv.level}
                  </div>
                )}
                <div>
                  <p className="font-bold">BD LV{lv.level}</p>
                  <label className="text-[10px] text-white/40 cursor-pointer inline-flex items-center gap-1 mt-1">
                    <ImageIcon size={12} /> Upload level badge
                    <input
                      type="file"
                      accept="image/*,.svg"
                      className="hidden"
                      onChange={(e) => {
                        const f = e.target.files?.[0];
                        if (f) onUploadBadge(lv.level, f);
                      }}
                    />
                  </label>
                </div>
              </div>
              {busy === `badge:${lv.level}` && (
                <Loader2 className="animate-spin text-white/50" size={16} />
              )}
            </div>

            <div className="grid md:grid-cols-3 gap-3">
              {levelSlots.map((slot) => {
                const key = `${slot.level}:${slot.feature_key}`;
                const img = slot.shop_item_image || slot.image_url;
                return (
                  <div
                    key={key}
                    className="rounded-xl bg-white/5 border border-white/10 p-3 space-y-2"
                  >
                    <p className="text-xs font-bold text-violet-200">
                      {FEATURE_LABELS[slot.feature_key] ?? slot.feature_key}
                    </p>
                    <div className="h-16 rounded-lg bg-black/40 flex items-center justify-center overflow-hidden">
                      {img ? (
                        <CdnImg src={img} alt="" className="max-h-14 object-contain" />
                      ) : (
                        <span className="text-[10px] text-white/30">Not set</span>
                      )}
                    </div>
                    <p className="text-[10px] text-white/40 truncate">
                      {slot.shop_item_name || slot.label || "—"}
                    </p>
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        disabled={busy === key}
                        onClick={() =>
                          setPicker({ level: slot.level, featureKey: slot.feature_key })
                        }
                        className="text-[10px] font-bold px-2 py-1 rounded-lg bg-violet-500/30 text-violet-100 inline-flex items-center gap-1"
                      >
                        <Search size={10} /> Shop
                      </button>
                      <label className="text-[10px] font-bold px-2 py-1 rounded-lg bg-sky-500/20 text-sky-100 cursor-pointer inline-flex items-center gap-1">
                        Upload
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => {
                            const f = e.target.files?.[0];
                            if (f) onUploadReward(slot.level, slot.feature_key, f);
                          }}
                        />
                      </label>
                    </div>
                    <label className="text-[10px] text-white/40 block">
                      Days
                      <input
                        type="number"
                        min={1}
                        defaultValue={slot.duration_days ?? 30}
                        className="mt-1 w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1 text-xs"
                        onBlur={(e) => {
                          const days = Number(e.target.value) || 30;
                          onDuration(slot.level, slot.feature_key, days);
                        }}
                      />
                    </label>
                    {busy === key && <Loader2 className="animate-spin" size={14} />}
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}

      <ShopItemPickerModal
        open={!!picker}
        featureKey={
          picker?.featureKey === "svip"
            ? "vip"
            : picker?.featureKey === "country_bd_badge"
              ? "badge"
              : picker?.featureKey === "bd_frame"
                ? "frame"
                : "all"
        }
        title={
          picker
            ? `Pick for LV${picker.level} · ${FEATURE_LABELS[picker.featureKey] ?? picker.featureKey}`
            : "Pick shop item"
        }
        onClose={() => setPicker(null)}
        onSelect={onPickShop}
      />
    </div>
  );
}
