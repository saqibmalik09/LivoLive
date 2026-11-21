"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  deleteMicDailyRewardLevel,
  updateMicDailyRewardRules,
  uploadMicDailyRewardImage,
  upsertMicDailyRewardLevel,
  type MicDailyRewardLevelRow,
  type MicShopOption,
} from "@/app/settings/mic-daily-rewards/actions";
import { Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
function secondsToMinutes(sec: number) {
  return Math.round(sec / 60);
}
export function MicDailyRewardManager({
  levels,
  rules: initialRules,
  shopItems,
}: {
  levels: MicDailyRewardLevelRow[];
  rules: string[];
  shopItems: MicShopOption[];
}) {
  const router = useRouter();
  const [levelRows, setLevelRows] = useState(levels);
  const [rules, setRules] = useState(initialRules.length > 0 ? initialRules : [""]);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [savingRules, setSavingRules] = useState(false);
  const [uploadingId, setUploadingId] = useState<string | null>(null);
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  function patchLevel(id: string, patch: Partial<MicDailyRewardLevelRow>) {
    setLevelRows((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)));
  }
  async function saveLevel(id: string) {
    const row = levelRows.find((l) => l.id === id);
    if (!row) return;
    setSavingId(id);
    const res = await upsertMicDailyRewardLevel({
      id: row.id,
      required_seconds: row.required_seconds,
      sort_order: row.sort_order,
      reward_type: row.reward_type ?? "coins",
      coin_amount: row.coin_amount,
      shop_item_id: row.shop_item_id,
      duration_days: row.duration_days,
      title: row.title,
      image_url: row.image_url,
      is_active: row.is_active,
    });
    setSavingId(null);
    if (res.success) router.refresh();
    else alert(res.error ?? "Save failed");
  }
  async function addLevel() {
    const nextMinutes =
      levelRows.length === 0
        ? 30
        : Math.max(...levelRows.map((l) => secondsToMinutes(l.required_seconds))) * 2;
    setAdding(true);
    const res = await upsertMicDailyRewardLevel({
      required_seconds: nextMinutes * 60,
      sort_order: nextMinutes,
      reward_type: "coins",
      coin_amount: 100,
      is_active: true,
    });
    setAdding(false);
    if (!res.success) {
      alert(res.error ?? "Add failed");
      return;
    }
    router.refresh();
  }
  async function removeLevel(id: string) {
    if (!confirm("Delete this mic reward tier?")) return;
    setDeletingId(id);
    const res = await deleteMicDailyRewardLevel(id);
    setDeletingId(null);
    if (!res.success) {
      alert(res.error ?? "Delete failed");
      return;
    }
    setLevelRows((rows) => rows.filter((l) => l.id !== id));
    router.refresh();
  }
  async function saveRules() {
    setSavingRules(true);
    const res = await updateMicDailyRewardRules(rules);
    setSavingRules(false);
    if (res.success) router.refresh();
    else alert(res.error ?? "Save failed");
  }
  async function handleUpload(id: string, file: File) {
    setUploadingId(id);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadMicDailyRewardImage(fd);
    setUploadingId(null);
    if (res.success && res.url) patchLevel(id, { image_url: res.url });
    else alert(res.error ?? "Upload failed");
  }
  return (
    <div className="space-y-10">
      <section className="glass-card p-6 space-y-5">
        <div className="flex items-center justify-between gap-4">
          <div>
            <h2 className="text-2xl font-black tracking-tight">Mic duration tiers</h2>
            <p className="text-sm text-white/50 mt-1">
              Users earn daily mic time while seated unmuted. Progress resets at 00:00 UTC+3. Each
              unlocked tier can be claimed once per day — coins or a shop asset.
            </p>
          </div>
          <button
            type="button"
            onClick={addLevel}
            disabled={adding}
            className="inline-flex items-center gap-2 shrink-0 rounded-xl bg-amber-500/20 border border-amber-400/30 px-4 py-2 text-sm font-bold text-amber-200 hover:bg-amber-500/30 disabled:opacity-50"
          >
            {adding ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
            Add tier
          </button>
        </div>

        <div className="space-y-4">
          {levelRows.map((row) => (
            <div
              key={row.id}
              className="p-4 rounded-2xl bg-black/30 border border-white/5 space-y-4"
            >
              <div className="flex flex-wrap items-end gap-3">
                <div className="min-w-[120px]">
                  <label className="text-[10px] uppercase tracking-widest text-white/40">
                    Required minutes
                  </label>
                  <input
                    type="number"
                    min={1}
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                    value={secondsToMinutes(row.required_seconds)}
                    onChange={(e) =>
                      patchLevel(row.id, {
                        required_seconds: Math.max(1, Number(e.target.value) || 1) * 60,
                        sort_order: Math.max(1, Number(e.target.value) || 1),
                      })
                    }
                  />
                </div>
                <div className="flex-1 min-w-[140px]">
                  <label className="text-[10px] uppercase tracking-widest text-white/40">
                    Reward type
                  </label>
                  <select
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                    value={row.reward_type ?? "coins"}
                    onChange={(e) =>
                      patchLevel(row.id, {
                        reward_type: e.target.value as "coins" | "shop_item",
                      })
                    }
                  >
                    <option value="coins">Coins</option>
                    <option value="shop_item">Shop asset</option>
                  </select>
                </div>
                <label className="flex items-center gap-2 text-sm text-white/70 pb-2">
                  <input
                    type="checkbox"
                    checked={row.is_active}
                    onChange={(e) => patchLevel(row.id, { is_active: e.target.checked })}
                  />
                  Active
                </label>
              </div>

              {(row.reward_type ?? "coins") === "coins" ? (
                <div className="max-w-xs">
                  <label className="text-[10px] uppercase tracking-widest text-white/40">
                    Coin reward
                  </label>
                  <input
                    type="number"
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                    value={row.coin_amount}
                    onChange={(e) =>
                      patchLevel(row.id, {
                        coin_amount: Number(e.target.value) || 0,
                      })
                    }
                  />
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <label className="text-[10px] uppercase tracking-widest text-white/40">
                      Shop item
                    </label>
                    <select
                      className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                      value={row.shop_item_id ?? ""}
                      onChange={(e) => {
                        const shop = shopItems.find((s) => s.id === e.target.value);
                        patchLevel(row.id, {
                          shop_item_id: e.target.value || null,
                          title: row.title || shop?.name || "",
                          image_url: row.image_url || shop?.image_url || "",
                          duration_days: row.duration_days ?? shop?.duration_days ?? null,
                        });
                      }}
                    >
                      <option value="">Select item</option>
                      {shopItems.map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.name}
                          {s.category ? ` (${s.category})` : ""}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="text-[10px] uppercase tracking-widest text-white/40">
                      Duration days (override)
                    </label>
                    <input
                      type="number"
                      min={0}
                      placeholder="Empty = shop default"
                      className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                      value={row.duration_days ?? ""}
                      onChange={(e) =>
                        patchLevel(row.id, {
                          duration_days: e.target.value === "" ? null : Number(e.target.value) || 0,
                        })
                      }
                    />
                  </div>
                  <div>
                    <label className="text-[10px] uppercase tracking-widest text-white/40">
                      Title
                    </label>
                    <input
                      className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                      value={row.title ?? ""}
                      onChange={(e) => patchLevel(row.id, { title: e.target.value })}
                    />
                  </div>
                  <div className="flex items-end gap-3">
                    <div className="w-14 h-14 rounded-xl overflow-hidden bg-black/40 border border-white/10">
                      {row.image_url ? (
                        <CdnImg src={row.image_url} alt="" className="w-full h-full object-cover" />
                      ) : null}
                    </div>
                    <div>
                      <input
                        ref={(el) => {
                          fileRefs.current[row.id] = el;
                        }}
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) void handleUpload(row.id, file);
                          e.target.value = "";
                        }}
                      />
                      <button
                        type="button"
                        disabled={uploadingId === row.id}
                        onClick={() => fileRefs.current[row.id]?.click()}
                        className="inline-flex items-center gap-2 px-3 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-bold uppercase tracking-widest"
                      >
                        {uploadingId === row.id ? (
                          <Loader2 size={14} className="animate-spin" />
                        ) : (
                          <Upload size={14} />
                        )}
                        Image
                      </button>
                    </div>
                  </div>
                </div>
              )}

              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => saveLevel(row.id)}
                  disabled={savingId === row.id}
                  className="inline-flex items-center gap-2 rounded-xl bg-amber-500/20 border border-amber-400/30 px-4 py-2 text-sm font-bold text-amber-200 disabled:opacity-50"
                >
                  {savingId === row.id ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Save size={16} />
                  )}
                  Save
                </button>
                <button
                  type="button"
                  onClick={() => removeLevel(row.id)}
                  disabled={deletingId === row.id}
                  className="inline-flex items-center justify-center h-10 w-10 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300 disabled:opacity-50"
                >
                  {deletingId === row.id ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Trash2 size={16} />
                  )}
                </button>
              </div>
            </div>
          ))}
          {levelRows.length === 0 && (
            <p className="text-white/40 text-sm">
              No tiers yet. Add 30 min / 1 hour (or any) mic duration rewards.
            </p>
          )}
        </div>
      </section>

      <section className="glass-card p-6 space-y-5">
        <div className="flex items-center justify-between gap-4">
          <h2 className="text-2xl font-black tracking-tight">Rules</h2>
          <button
            type="button"
            onClick={() => setRules((prev) => [...prev, ""])}
            className="inline-flex items-center gap-2 rounded-xl bg-white/5 border border-white/10 px-3 py-2 text-xs font-bold uppercase tracking-widest text-white/70"
          >
            <Plus size={14} /> Add
          </button>
        </div>
        <div className="space-y-3">
          {rules.map((rule, idx) => (
            <div key={idx} className="flex gap-2">
              <span className="pt-3 text-white/30 text-sm w-6">{idx + 1}.</span>
              <textarea
                className="flex-1 rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm min-h-[68px]"
                value={rule}
                onChange={(e) =>
                  setRules((prev) => prev.map((r, i) => (i === idx ? e.target.value : r)))
                }
              />
              <button
                type="button"
                onClick={() => setRules((prev) => prev.filter((_, i) => i !== idx))}
                className="h-10 w-10 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300 flex items-center justify-center"
              >
                <Trash2 size={16} />
              </button>
            </div>
          ))}
        </div>
        <button
          type="button"
          onClick={saveRules}
          disabled={savingRules}
          className="inline-flex items-center gap-2 rounded-xl bg-amber-500/20 border border-amber-400/30 px-4 py-2 text-sm font-bold text-amber-200 disabled:opacity-50"
        >
          {savingRules ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
          Save rules
        </button>
      </section>
    </div>
  );
}
