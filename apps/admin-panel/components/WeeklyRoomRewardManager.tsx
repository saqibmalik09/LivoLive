"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  deleteWeeklyRoomRewardLevel,
  updateWeeklyRoomRewardRules,
  uploadWeeklyRoomRewardImage,
  upsertWeeklyRoomRewardLevel,
  type WeeklyRoomRewardLevelRow,
  type WeeklyShopOption,
} from "@/app/settings/weekly-room-rewards/actions";
import { Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
export function WeeklyRoomRewardManager({
  levels,
  rules: initialRules,
  shopItems,
}: {
  levels: WeeklyRoomRewardLevelRow[];
  rules: string[];
  shopItems: WeeklyShopOption[];
}) {
  const router = useRouter();
  const [levelRows, setLevelRows] = useState(levels);
  const [rules, setRules] = useState(initialRules.length > 0 ? initialRules : [""]);
  const [savingLevel, setSavingLevel] = useState<number | null>(null);
  const [deletingLevel, setDeletingLevel] = useState<number | null>(null);
  const [adding, setAdding] = useState(false);
  const [savingRules, setSavingRules] = useState(false);
  const [uploadingLevel, setUploadingLevel] = useState<number | null>(null);
  const fileRefs = useRef<Record<number, HTMLInputElement | null>>({});
  function patchLevel(level: number, patch: Partial<WeeklyRoomRewardLevelRow>) {
    setLevelRows((prev) => prev.map((l) => (l.level === level ? { ...l, ...patch } : l)));
  }
  async function saveLevel(level: number) {
    const row = levelRows.find((l) => l.level === level);
    if (!row) return;
    setSavingLevel(level);
    const res = await upsertWeeklyRoomRewardLevel({
      level: row.level,
      required_points: row.required_points,
      coin_reward: row.coin_reward,
      reward_type: row.reward_type ?? "coins",
      shop_item_id: row.shop_item_id,
      duration_days: row.duration_days,
      title: row.title,
      image_url: row.image_url,
      is_active: row.is_active,
    });
    setSavingLevel(null);
    if (res.success) router.refresh();
    else alert(res.error ?? "Save failed");
  }
  async function addLevel() {
    const nextLevel = levelRows.reduce((max, l) => Math.max(max, l.level), 0) + 1;
    const prev = levelRows[levelRows.length - 1];
    const required = prev ? Math.max(prev.required_points * 2, prev.required_points + 1) : 100000;
    const coins = prev ? Math.max(prev.coin_reward * 2, prev.coin_reward + 1) : 10000;
    setAdding(true);
    const res = await upsertWeeklyRoomRewardLevel({
      level: nextLevel,
      required_points: required,
      coin_reward: coins,
      reward_type: "coins",
      is_active: true,
    });
    setAdding(false);
    if (!res.success) {
      alert(res.error ?? "Add failed");
      return;
    }
    setLevelRows((rows) => [
      ...rows,
      {
        level: nextLevel,
        required_points: required,
        coin_reward: coins,
        reward_type: "coins",
        shop_item_id: null,
        duration_days: null,
        title: "",
        image_url: "",
        is_active: true,
        sort_order: nextLevel,
      },
    ]);
    router.refresh();
  }
  async function removeLevel(level: number) {
    if (!confirm(`Delete level ${level}?`)) return;
    setDeletingLevel(level);
    const res = await deleteWeeklyRoomRewardLevel(level);
    setDeletingLevel(null);
    if (!res.success) {
      alert(res.error ?? "Delete failed");
      return;
    }
    setLevelRows((rows) => rows.filter((l) => l.level !== level));
    router.refresh();
  }
  async function saveRules() {
    setSavingRules(true);
    const res = await updateWeeklyRoomRewardRules(rules);
    setSavingRules(false);
    if (res.success) router.refresh();
    else alert(res.error ?? "Save failed");
  }
  async function handleUpload(level: number, file: File) {
    setUploadingLevel(level);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadWeeklyRoomRewardImage(fd);
    setUploadingLevel(null);
    if (res.success && res.url) {
      patchLevel(level, { image_url: res.url });
    } else {
      alert(res.error ?? "Upload failed");
    }
  }
  return (
    <div className="space-y-10">
      <section className="glass-card p-6 space-y-5">
        <div className="flex items-center justify-between gap-4">
          <div>
            <h2 className="text-2xl font-black tracking-tight">Room Reward levels</h2>
            <p className="text-sm text-white/50 mt-1">
              Room Charm = gift coins received in the room (Sunday–Saturday UTC+3). After the week
              ends, the owner can claim only the highest unlocked level within 6 days. Each level
              can pay <strong className="text-white/70">coins</strong> or a{" "}
              <strong className="text-white/70">shop asset</strong> (frame / entrance / …) with
              optional duration.
            </p>
          </div>
          <button
            type="button"
            onClick={addLevel}
            disabled={adding}
            className="inline-flex items-center gap-2 shrink-0 rounded-xl bg-amber-500/20 border border-amber-400/30 px-4 py-2 text-sm font-bold text-amber-200 hover:bg-amber-500/30 disabled:opacity-50"
          >
            {adding ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
            Add level
          </button>
        </div>
        <div className="space-y-4">
          {levelRows.map((row) => (
            <div
              key={row.level}
              className="p-4 rounded-2xl bg-black/30 border border-white/5 space-y-4"
            >
              <div className="flex flex-wrap items-end gap-3">
                <div className="w-16">
                  <label className="text-[10px] uppercase tracking-widest text-white/40">
                    Level
                  </label>
                  <div className="text-xl font-black text-amber-300">Lv{row.level}</div>
                </div>
                <div className="flex-1 min-w-[140px]">
                  <label className="text-[10px] uppercase tracking-widest text-white/40">
                    Room Target
                  </label>
                  <input
                    type="number"
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                    value={row.required_points}
                    onChange={(e) =>
                      patchLevel(row.level, {
                        required_points: Number(e.target.value) || 0,
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
                      patchLevel(row.level, {
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
                    onChange={(e) => patchLevel(row.level, { is_active: e.target.checked })}
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
                    value={row.coin_reward}
                    onChange={(e) =>
                      patchLevel(row.level, {
                        coin_reward: Number(e.target.value) || 0,
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
                        patchLevel(row.level, {
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
                        patchLevel(row.level, {
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
                      onChange={(e) => patchLevel(row.level, { title: e.target.value })}
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
                          fileRefs.current[row.level] = el;
                        }}
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) void handleUpload(row.level, file);
                          e.target.value = "";
                        }}
                      />
                      <button
                        type="button"
                        disabled={uploadingLevel === row.level}
                        onClick={() => fileRefs.current[row.level]?.click()}
                        className="inline-flex items-center gap-2 px-3 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-bold uppercase tracking-widest"
                      >
                        {uploadingLevel === row.level ? (
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
                  onClick={() => saveLevel(row.level)}
                  disabled={savingLevel === row.level}
                  className="inline-flex items-center gap-2 rounded-xl bg-amber-500/20 border border-amber-400/30 px-4 py-2 text-sm font-bold text-amber-200 hover:bg-amber-500/30 disabled:opacity-50"
                >
                  {savingLevel === row.level ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Save size={16} />
                  )}
                  Save
                </button>
                <button
                  type="button"
                  onClick={() => removeLevel(row.level)}
                  disabled={deletingLevel === row.level}
                  className="inline-flex items-center justify-center h-10 w-10 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300 hover:bg-red-500/20 disabled:opacity-50"
                  title="Delete level"
                >
                  {deletingLevel === row.level ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Trash2 size={16} />
                  )}
                </button>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="glass-card p-6 space-y-5">
        <div className="flex items-center justify-between gap-4">
          <h2 className="text-2xl font-black tracking-tight">Rules</h2>
          <button
            type="button"
            onClick={() => setRules((prev) => [...prev, ""])}
            className="inline-flex items-center gap-2 rounded-xl bg-white/5 border border-white/10 px-3 py-2 text-xs font-bold uppercase tracking-widest text-white/70 hover:bg-white/10"
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
          className="inline-flex items-center gap-2 rounded-xl bg-amber-500/20 border border-amber-400/30 px-4 py-2 text-sm font-bold text-amber-200 hover:bg-amber-500/30 disabled:opacity-50"
        >
          {savingRules ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
          Save rules
        </button>
      </section>
    </div>
  );
}
