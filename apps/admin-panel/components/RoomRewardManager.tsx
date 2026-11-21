"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  deleteRoomRewardItem,
  updateRoomRewardRules,
  uploadRoomRewardImage,
  upsertRoomRewardItem,
  upsertRoomRewardLevel,
  type RoomRewardItemRow,
  type RoomRewardLevelRow,
} from "@/app/settings/room-rewards/actions";
import { Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
type ShopOption = {
  id: string;
  name: string;
  image_url: string;
  price_coins: number;
};
export function RoomRewardManager({
  levels,
  items,
  rules: initialRules,
  shopItems,
}: {
  levels: RoomRewardLevelRow[];
  items: RoomRewardItemRow[];
  rules: string[];
  shopItems: ShopOption[];
}) {
  const router = useRouter();
  const [levelRows, setLevelRows] = useState(levels);
  const [rules, setRules] = useState(initialRules.length > 0 ? initialRules : [""]);
  const [savingLevel, setSavingLevel] = useState<number | null>(null);
  const [savingRules, setSavingRules] = useState(false);
  const [levelFilter, setLevelFilter] = useState<number | "all">("all");
  const [editing, setEditing] = useState<Partial<RoomRewardItemRow> | null>(null);
  const [savingItem, setSavingItem] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const filteredItems =
    levelFilter === "all" ? items : items.filter((i) => i.level === levelFilter);
  async function saveLevel(level: number) {
    const row = levelRows.find((l) => l.level === level);
    if (!row) return;
    setSavingLevel(level);
    const res = await upsertRoomRewardLevel({
      level: row.level,
      required_points: row.required_points,
      is_active: row.is_active,
    });
    setSavingLevel(null);
    if (res.success) router.refresh();
    else alert(res.error ?? "Save failed");
  }
  async function saveRules() {
    setSavingRules(true);
    const res = await updateRoomRewardRules(rules);
    setSavingRules(false);
    if (res.success) router.refresh();
    else alert(res.error ?? "Save failed");
  }
  function startNew(level = 1) {
    setEditing({
      level,
      title: "",
      image_url: "",
      reward_type: "coins",
      coin_amount: 100,
      shop_item_id: null,
      weight: 1,
      sort_order: items.filter((i) => i.level === level).length,
      is_active: true,
      is_featured: false,
    });
  }
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !editing) return;
    setUploading(true);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadRoomRewardImage(fd);
    if (res.success && res.url) {
      setEditing((prev) => ({ ...prev, image_url: res.url }));
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown"}`);
    }
    setUploading(false);
    e.target.value = "";
  }
  async function handleSaveItem(e: React.FormEvent) {
    e.preventDefault();
    if (!editing?.level || !editing.reward_type) return;
    setSavingItem(true);
    const res = await upsertRoomRewardItem({
      id: editing.id,
      level: editing.level,
      title: editing.title ?? "",
      image_url: editing.image_url ?? "",
      reward_type: editing.reward_type,
      coin_amount: editing.coin_amount ?? 0,
      shop_item_id: editing.shop_item_id,
      weight: editing.weight ?? 1,
      sort_order: editing.sort_order ?? 0,
      is_active: editing.is_active ?? true,
      is_featured: editing.is_featured ?? false,
    });
    setSavingItem(false);
    if (res.success) {
      setEditing(null);
      router.refresh();
    } else {
      alert(res.error ?? "Save failed");
    }
  }
  async function handleDelete(id: string) {
    if (!confirm("Delete this reward?")) return;
    setDeletingId(id);
    const res = await deleteRoomRewardItem(id);
    setDeletingId(null);
    if (res.success) router.refresh();
    else alert(res.error ?? "Delete failed");
  }
  return (
    <div className="space-y-10">
      <section className="glass-card p-6 space-y-5">
        <h2 className="text-2xl font-black tracking-tight">Level points</h2>
        <p className="text-sm text-white/50">
          Energy comes from gift coins the user sends in that room. Set required points per Lv1–Lv5.
        </p>
        <div className="space-y-3">
          {levelRows.map((row, idx) => (
            <div
              key={row.level}
              className="flex flex-col md:flex-row md:items-center gap-3 bg-black/30 border border-white/10 rounded-2xl p-4"
            >
              <span className="font-black text-amber-300 w-14">Lv{row.level}</span>
              <label className="flex-1 space-y-1">
                <span className="text-[10px] uppercase tracking-widest text-white/40 font-black">
                  Required points
                </span>
                <input
                  type="number"
                  value={row.required_points}
                  onChange={(e) => {
                    const v = parseInt(e.target.value || "0", 10);
                    setLevelRows((prev) =>
                      prev.map((r, i) => (i === idx ? { ...r, required_points: v } : r)),
                    );
                  }}
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                />
              </label>
              <label className="flex items-center gap-2 text-sm text-white/60">
                <input
                  type="checkbox"
                  checked={row.is_active}
                  onChange={(e) =>
                    setLevelRows((prev) =>
                      prev.map((r, i) => (i === idx ? { ...r, is_active: e.target.checked } : r)),
                    )
                  }
                />
                Active
              </label>
              <button
                type="button"
                disabled={savingLevel === row.level}
                onClick={() => saveLevel(row.level)}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-amber-500 text-black text-xs font-black uppercase tracking-widest disabled:opacity-50"
              >
                {savingLevel === row.level ? (
                  <Loader2 size={14} className="animate-spin" />
                ) : (
                  <Save size={14} />
                )}
                Save
              </button>
            </div>
          ))}
        </div>
      </section>

      <section className="glass-card p-6 space-y-5">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-2xl font-black tracking-tight">Reward pool</h2>
          <div className="flex-1" />
          {([1, 2, 3, 4, 5] as const).map((lv) => (
            <button
              key={lv}
              type="button"
              onClick={() => setLevelFilter(lv)}
              className={`px-3 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-widest border ${
                levelFilter === lv
                  ? "bg-violet-500 text-white border-violet-400"
                  : "border-white/10 text-white/40"
              }`}
            >
              Lv{lv}
            </button>
          ))}
          <button
            type="button"
            onClick={() => setLevelFilter("all")}
            className={`px-3 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-widest border ${
              levelFilter === "all"
                ? "bg-white text-black border-white"
                : "border-white/10 text-white/40"
            }`}
          >
            All
          </button>
          <button
            type="button"
            onClick={() => startNew(levelFilter === "all" ? 1 : levelFilter)}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-sky-500/20 border border-sky-400/30 text-sky-200 text-xs font-black uppercase tracking-widest"
          >
            <Plus size={14} /> Add reward
          </button>
        </div>

        {editing && (
          <form
            onSubmit={handleSaveItem}
            className="border border-amber-500/20 rounded-2xl p-5 space-y-4 bg-black/20"
          >
            <div className="flex justify-between items-center">
              <h3 className="font-bold text-lg">{editing.id ? "Edit" : "New"} reward</h3>
              <button
                type="button"
                onClick={() => setEditing(null)}
                className="text-xs uppercase tracking-widest text-white/40"
              >
                Cancel
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <label className="space-y-1 block">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Level
                </span>
                <select
                  value={editing.level ?? 1}
                  onChange={(e) => setEditing({ ...editing, level: parseInt(e.target.value, 10) })}
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                >
                  {[1, 2, 3, 4, 5].map((lv) => (
                    <option key={lv} value={lv}>
                      Lv{lv}
                    </option>
                  ))}
                </select>
              </label>
              <label className="space-y-1 block">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Title
                </span>
                <input
                  value={editing.title ?? ""}
                  onChange={(e) => setEditing({ ...editing, title: e.target.value })}
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                />
              </label>
              <label className="space-y-1 block">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Type
                </span>
                <select
                  value={editing.reward_type ?? "coins"}
                  onChange={(e) =>
                    setEditing({
                      ...editing,
                      reward_type: e.target.value as "coins" | "shop_item",
                    })
                  }
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                >
                  <option value="coins">Coins</option>
                  <option value="shop_item">Shop item</option>
                </select>
              </label>
              {editing.reward_type === "coins" ? (
                <label className="space-y-1 block">
                  <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                    Coin amount
                  </span>
                  <input
                    type="number"
                    value={editing.coin_amount ?? 0}
                    onChange={(e) =>
                      setEditing({
                        ...editing,
                        coin_amount: parseInt(e.target.value || "0", 10),
                      })
                    }
                    className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                  />
                </label>
              ) : (
                <label className="space-y-1 block">
                  <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                    Shop item
                  </span>
                  <select
                    value={editing.shop_item_id ?? ""}
                    onChange={(e) => {
                      const shop = shopItems.find((s) => s.id === e.target.value);
                      setEditing({
                        ...editing,
                        shop_item_id: e.target.value || null,
                        title: editing.title || shop?.name || "",
                        image_url: editing.image_url || shop?.image_url || "",
                      });
                    }}
                    className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                  >
                    <option value="">Select item</option>
                    {shopItems.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name}
                      </option>
                    ))}
                  </select>
                </label>
              )}
              <label className="space-y-1 block">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Weight
                </span>
                <input
                  type="number"
                  value={editing.weight ?? 1}
                  onChange={(e) =>
                    setEditing({
                      ...editing,
                      weight: parseInt(e.target.value || "1", 10),
                    })
                  }
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                />
              </label>
              <label className="space-y-1 block">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Sort order
                </span>
                <input
                  type="number"
                  value={editing.sort_order ?? 0}
                  onChange={(e) =>
                    setEditing({
                      ...editing,
                      sort_order: parseInt(e.target.value || "0", 10),
                    })
                  }
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
                />
              </label>
            </div>

            <div className="flex gap-4 items-start">
              <div className="w-24 h-24 rounded-2xl overflow-hidden bg-black/40 border border-white/10">
                {editing.image_url ? (
                  <CdnImg src={editing.image_url} alt="" className="w-full h-full object-cover" />
                ) : null}
              </div>
              <div className="space-y-2">
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={handleUpload}
                />
                <button
                  type="button"
                  disabled={uploading}
                  onClick={() => fileRef.current?.click()}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-black uppercase tracking-widest"
                >
                  {uploading ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Upload size={14} />
                  )}
                  Upload image
                </button>
                <label className="flex items-center gap-2 text-sm text-white/60">
                  <input
                    type="checkbox"
                    checked={editing.is_featured ?? false}
                    onChange={(e) => setEditing({ ...editing, is_featured: e.target.checked })}
                  />
                  Featured (large left cell)
                </label>
                <label className="flex items-center gap-2 text-sm text-white/60">
                  <input
                    type="checkbox"
                    checked={editing.is_active ?? true}
                    onChange={(e) => setEditing({ ...editing, is_active: e.target.checked })}
                  />
                  Active
                </label>
              </div>
            </div>

            <button
              type="submit"
              disabled={savingItem || !editing.image_url}
              className="inline-flex items-center gap-2 bg-gradient-to-r from-amber-500 to-orange-500 text-black px-6 py-3 rounded-2xl font-black uppercase tracking-widest disabled:opacity-50"
            >
              {savingItem ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
              Save reward
            </button>
          </form>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {filteredItems.map((item) => (
            <div key={item.id} className="glass-card p-4 space-y-3">
              <div className="aspect-square rounded-2xl overflow-hidden bg-black/40 border border-white/5">
                <CdnImg src={item.image_url} alt="" className="w-full h-full object-cover" />
              </div>
              <div className="space-y-1">
                <p className="text-[9px] font-black uppercase tracking-widest text-amber-300">
                  Lv{item.level}
                  {item.is_featured ? " · Featured" : ""}
                  {!item.is_active ? " · Off" : ""}
                </p>
                <p className="font-bold truncate">{item.title}</p>
                <p className="text-xs text-white/40">
                  {item.reward_type === "coins" ? `${item.coin_amount} coins` : "Shop item"} ·
                  weight {item.weight}
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setEditing(item)}
                  className="flex-1 py-2 rounded-xl bg-white/5 border border-white/10 text-[10px] font-black uppercase tracking-widest"
                >
                  Edit
                </button>
                <button
                  type="button"
                  disabled={deletingId === item.id}
                  onClick={() => handleDelete(item.id)}
                  className="px-3 py-2 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300"
                >
                  {deletingId === item.id ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Trash2 size={14} />
                  )}
                </button>
              </div>
            </div>
          ))}
          {filteredItems.length === 0 && (
            <p className="text-white/40 text-sm col-span-full">
              No rewards yet. Add coin or shop-item rewards per level.
            </p>
          )}
        </div>
      </section>

      <section className="glass-card p-6 space-y-5">
        <h2 className="text-2xl font-black tracking-tight">Rules text</h2>
        <div className="space-y-3">
          {rules.map((rule, idx) => (
            <div key={idx} className="flex gap-2">
              <textarea
                value={rule}
                onChange={(e) =>
                  setRules((prev) => prev.map((r, i) => (i === idx ? e.target.value : r)))
                }
                rows={2}
                className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm"
              />
              <button
                type="button"
                onClick={() => setRules((prev) => prev.filter((_, i) => i !== idx))}
                className="px-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300"
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
          <button
            type="button"
            onClick={() => setRules((prev) => [...prev, ""])}
            className="inline-flex items-center gap-2 text-xs font-black uppercase tracking-widest text-white/50"
          >
            <Plus size={14} /> Add rule line
          </button>
        </div>
        <button
          type="button"
          disabled={savingRules}
          onClick={saveRules}
          className="inline-flex items-center gap-2 bg-gradient-to-r from-amber-500 to-orange-500 text-black px-6 py-3 rounded-2xl font-black uppercase tracking-widest disabled:opacity-50"
        >
          {savingRules ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
          Save rules
        </button>
      </section>
    </div>
  );
}
