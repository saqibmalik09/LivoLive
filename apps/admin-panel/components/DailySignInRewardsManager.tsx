"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  upsertDailySignInReward,
  uploadDailySignInImage,
  type DailySignInRewardRow,
} from "@/app/settings/daily-signin/actions";
import { Loader2, Save, Upload } from "lucide-react";
type ShopOption = {
  id: string;
  name: string;
  image_url: string;
  price_coins: number;
};
export function DailySignInRewardsManager({
  rows: initialRows,
  shopItems,
}: {
  rows: DailySignInRewardRow[];
  shopItems: ShopOption[];
}) {
  const router = useRouter();
  const [rows, setRows] = useState(initialRows);
  const [savingDay, setSavingDay] = useState<number | null>(null);
  const [uploadingDay, setUploadingDay] = useState<number | null>(null);
  const fileRefs = useRef<Record<number, HTMLInputElement | null>>({});
  function patch(day: number, partial: Partial<DailySignInRewardRow>) {
    setRows((prev) => prev.map((r) => (r.day_number === day ? { ...r, ...partial } : r)));
  }
  async function save(day: number) {
    const row = rows.find((r) => r.day_number === day);
    if (!row) return;
    setSavingDay(day);
    const res = await upsertDailySignInReward({
      day_number: row.day_number,
      reward_type: row.reward_type,
      coin_amount: row.coin_amount,
      shop_item_id: row.shop_item_id,
      image_url: row.image_url,
      label: row.label,
      is_active: row.is_active,
    });
    setSavingDay(null);
    if (res.success) router.refresh();
    else alert(res.error ?? "Save failed");
  }
  async function handleUpload(day: number, e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingDay(day);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadDailySignInImage(fd);
    if (res.success && res.url) {
      patch(day, { image_url: res.url });
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown"}`);
    }
    setUploadingDay(null);
    e.target.value = "";
  }
  return (
    <div className="space-y-4">
      <p className="text-sm text-white/50">
        Each day can award <strong className="text-white/80">coins</strong> or a{" "}
        <strong className="text-white/80">shop asset</strong> (frame, car, entrance…). Missing a day
        resets the user streak to Day 1.
      </p>

      {rows.map((row) => {
        const shop = shopItems.find((s) => s.id === row.shop_item_id);
        const preview =
          row.image_url || (row.reward_type === "shop_item" ? shop?.image_url : "") || "";
        return (
          <div
            key={row.day_number}
            className="glass-card p-5 flex flex-col gap-4 md:flex-row md:items-start"
          >
            <div className="w-16 shrink-0 text-center">
              <div className="text-3xl font-black text-amber-300">D{row.day_number}</div>
              <label className="mt-2 flex items-center justify-center gap-1 text-[10px] uppercase tracking-wider text-white/40">
                <input
                  type="checkbox"
                  checked={row.is_active}
                  onChange={(e) => patch(row.day_number, { is_active: e.target.checked })}
                />
                Active
              </label>
            </div>

            <div className="w-20 h-20 shrink-0 rounded-2xl bg-black/30 border border-white/10 overflow-hidden flex items-center justify-center">
              {preview ? (
                <CdnImg src={preview} alt="" className="w-full h-full object-contain" />
              ) : (
                <span className="text-white/20 text-xs">No img</span>
              )}
            </div>

            <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-3">
              <label className="block text-xs text-white/50">
                Label
                <input
                  className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm text-white"
                  value={row.label ?? ""}
                  onChange={(e) => patch(row.day_number, { label: e.target.value })}
                />
              </label>

              <label className="block text-xs text-white/50">
                Reward type
                <select
                  className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm text-white"
                  value={row.reward_type}
                  onChange={(e) =>
                    patch(row.day_number, {
                      reward_type: e.target.value as "coins" | "shop_item",
                    })
                  }
                >
                  <option value="coins">Coins</option>
                  <option value="shop_item">Shop asset</option>
                </select>
              </label>

              {row.reward_type === "coins" ? (
                <label className="block text-xs text-white/50">
                  Coin amount
                  <input
                    type="number"
                    min={1}
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm text-white"
                    value={row.coin_amount}
                    onChange={(e) =>
                      patch(row.day_number, {
                        coin_amount: Number(e.target.value) || 0,
                      })
                    }
                  />
                </label>
              ) : (
                <label className="block text-xs text-white/50 sm:col-span-2">
                  Shop item
                  <select
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm text-white"
                    value={row.shop_item_id ?? ""}
                    onChange={(e) =>
                      patch(row.day_number, {
                        shop_item_id: e.target.value || null,
                        image_url:
                          shopItems.find((s) => s.id === e.target.value)?.image_url ||
                          row.image_url,
                      })
                    }
                  >
                    <option value="">Select item…</option>
                    {shopItems.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name} ({s.price_coins}c)
                      </option>
                    ))}
                  </select>
                </label>
              )}

              <div className="flex items-end gap-2 sm:col-span-2">
                <input
                  ref={(el) => {
                    fileRefs.current[row.day_number] = el;
                  }}
                  type="file"
                  accept="image/*,.svga"
                  className="hidden"
                  onChange={(e) => handleUpload(row.day_number, e)}
                />
                <button
                  type="button"
                  onClick={() => fileRefs.current[row.day_number]?.click()}
                  disabled={uploadingDay === row.day_number}
                  className="inline-flex items-center gap-2 rounded-xl border border-white/15 px-3 py-2 text-xs font-bold text-white/80 hover:bg-white/5"
                >
                  {uploadingDay === row.day_number ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Upload size={14} />
                  )}
                  Custom image
                </button>
                <button
                  type="button"
                  onClick={() => save(row.day_number)}
                  disabled={savingDay === row.day_number}
                  className="ml-auto inline-flex items-center gap-2 rounded-xl bg-amber-500/90 hover:bg-amber-400 px-4 py-2 text-xs font-black text-black"
                >
                  {savingDay === row.day_number ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Save size={14} />
                  )}
                  Save Day {row.day_number}
                </button>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
