"use client";
import { useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  deleteHomeGamesRowItem,
  setHomeGamesRowOrder,
  uploadHomeGamesRowImage,
  upsertHomeGamesRowItem,
  type HomeGamesRowGameOption,
  type HomeGamesRowItem,
} from "@/app/settings/home-games/actions";
import { ArrowDown, ArrowUp, Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
export function HomeGamesRowManager({
  items: initialItems,
  games,
}: {
  items: HomeGamesRowItem[];
  games: HomeGamesRowGameOption[];
}) {
  const router = useRouter();
  const [items, setItems] = useState(initialItems);
  const [editing, setEditing] = useState<Partial<HomeGamesRowItem> | null>(null);
  const [pending, startTransition] = useTransition();
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const usedSlugs = useMemo(() => new Set(items.map((i) => i.game_slug)), [items]);
  const availableGames = games.filter((g) => !usedSlugs.has(g.slug));
  function startNew() {
    const g = availableGames[0];
    setEditing({
      game_slug: g?.slug ?? "",
      title: g?.name ?? "",
      image_url: g?.icon_url ?? "",
      sort_order: items.length,
      is_active: true,
    });
  }
  async function move(id: string, dir: -1 | 1) {
    const idx = items.findIndex((i) => i.id === id);
    const swap = idx + dir;
    if (idx < 0 || swap < 0 || swap >= items.length) return;
    const next = [...items];
    const tmp = next[idx];
    next[idx] = next[swap];
    next[swap] = tmp;
    setItems(next);
    startTransition(async () => {
      const res = await setHomeGamesRowOrder(next.map((i) => i.id));
      if (!res.success) {
        alert(res.error);
        setItems(initialItems);
      } else {
        router.refresh();
      }
    });
  }
  async function toggleActive(item: HomeGamesRowItem) {
    const res = await upsertHomeGamesRowItem({
      id: item.id,
      game_slug: item.game_slug,
      title: item.title,
      image_url: item.image_url,
      sort_order: item.sort_order,
      is_active: !item.is_active,
    });
    if (!res.success) alert(res.error);
    else router.refresh();
  }
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !editing) return;
    setUploading(true);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadHomeGamesRowImage(fd);
    if (res.success && res.url) {
      setEditing((prev) => ({ ...prev, image_url: res.url }));
    } else {
      alert(res.error ?? "Upload failed");
    }
    setUploading(false);
    e.target.value = "";
  }
  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!editing?.game_slug) return;
    const res = await upsertHomeGamesRowItem({
      id: editing.id,
      game_slug: editing.game_slug,
      title: editing.title,
      image_url: editing.image_url,
      sort_order: editing.sort_order ?? items.length,
      is_active: editing.is_active ?? true,
    });
    if (!res.success) {
      alert(res.error);
      return;
    }
    setEditing(null);
    router.refresh();
  }
  async function handleDelete(id: string) {
    if (!confirm("Remove this game from the home row?")) return;
    const res = await deleteHomeGamesRowItem(id);
    if (!res.success) alert(res.error);
    else router.refresh();
  }
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-white/50">
          Order = left → right on Home Hot (between Ranking Podium and Hot Cards). Icon falls back
          to Game Control icon if empty.
        </p>
        <button
          type="button"
          onClick={startNew}
          disabled={availableGames.length === 0}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-amber-500/20 border border-amber-500/30 text-amber-200 text-sm font-bold disabled:opacity-40"
        >
          <Plus size={16} />
          Add game
        </button>
      </div>

      <div className="glass-card overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-[10px] uppercase tracking-widest text-white/30 border-b border-white/10">
              <th className="p-4">Order</th>
              <th className="p-4">Icon</th>
              <th className="p-4">Game</th>
              <th className="p-4">Active</th>
              <th className="p-4 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item, index) => (
              <tr key={item.id} className="border-t border-white/5">
                <td className="p-4">
                  <div className="flex items-center gap-1">
                    <button
                      type="button"
                      disabled={pending || index === 0}
                      onClick={() => move(item.id, -1)}
                      className="p-2 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30"
                    >
                      <ArrowUp size={14} />
                    </button>
                    <button
                      type="button"
                      disabled={pending || index === items.length - 1}
                      onClick={() => move(item.id, 1)}
                      className="p-2 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30"
                    >
                      <ArrowDown size={14} />
                    </button>
                    <span className="ml-2 font-black text-white/40">{index + 1}</span>
                  </div>
                </td>
                <td className="p-4">
                  {item.image_url ? (
                    <img
                      src={item.image_url}
                      alt=""
                      className="w-12 h-12 rounded-2xl object-cover border border-white/10"
                    />
                  ) : (
                    <div className="w-12 h-12 rounded-2xl bg-white/5 border border-white/10" />
                  )}
                </td>
                <td className="p-4">
                  <p className="font-bold">{item.title || item.game_slug}</p>
                  <p className="text-xs text-white/40">{item.game_slug}</p>
                </td>
                <td className="p-4">
                  <button
                    type="button"
                    onClick={() => toggleActive(item)}
                    className={`px-3 py-1 rounded-lg text-[10px] font-black uppercase tracking-widest ${
                      item.is_active
                        ? "bg-emerald-500/20 text-emerald-300"
                        : "bg-white/10 text-white/40"
                    }`}
                  >
                    {item.is_active ? "On" : "Off"}
                  </button>
                </td>
                <td className="p-4 text-right space-x-2">
                  <button
                    type="button"
                    onClick={() => setEditing(item)}
                    className="px-3 py-1.5 rounded-lg bg-white/5 text-xs font-bold hover:bg-white/10"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDelete(item.id)}
                    className="px-3 py-1.5 rounded-lg bg-red-500/10 text-red-300 text-xs font-bold hover:bg-red-500/20"
                  >
                    <Trash2 size={14} className="inline" />
                  </button>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={5} className="p-8 text-center text-white/40">
                  No games in the home row yet. Add from Game Control list.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {editing && (
        <form onSubmit={handleSave} className="glass-card p-6 space-y-4 border border-amber-500/20">
          <h3 className="text-lg font-black">
            {editing.id ? "Edit home game icon" : "Add home game icon"}
          </h3>
          <div className="grid sm:grid-cols-2 gap-4">
            <label className="block space-y-1">
              <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                Game
              </span>
              <select
                className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                value={editing.game_slug ?? ""}
                disabled={!!editing.id}
                onChange={(e) => {
                  const g = games.find((x) => x.slug === e.target.value);
                  setEditing((prev) => ({
                    ...prev,
                    game_slug: e.target.value,
                    title: prev?.title || g?.name || "",
                    image_url: prev?.image_url || g?.icon_url || "",
                  }));
                }}
              >
                <option value="">Select…</option>
                {(editing.id ? games : availableGames).map((g) => (
                  <option key={g.slug} value={g.slug}>
                    {g.name} ({g.slug})
                  </option>
                ))}
              </select>
            </label>
            <label className="block space-y-1">
              <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                Display title
              </span>
              <input
                className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                value={editing.title ?? ""}
                onChange={(e) => setEditing((prev) => ({ ...prev, title: e.target.value }))}
              />
            </label>
          </div>
          <div className="flex flex-wrap items-end gap-4">
            <label className="block space-y-1 flex-1 min-w-[220px]">
              <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                Icon URL (optional override)
              </span>
              <input
                className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                value={editing.image_url ?? ""}
                onChange={(e) =>
                  setEditing((prev) => ({
                    ...prev,
                    image_url: e.target.value,
                  }))
                }
              />
            </label>
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              disabled={uploading}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-sm font-bold"
            >
              {uploading ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
              Upload
            </button>
            <input
              ref={fileRef}
              type="file"
              accept="image/*,.webp"
              className="hidden"
              onChange={handleUpload}
            />
            {editing.image_url ? (
              <img
                src={editing.image_url}
                alt=""
                className="w-14 h-14 rounded-2xl object-cover border border-white/10"
              />
            ) : null}
          </div>
          <label className="inline-flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={editing.is_active ?? true}
              onChange={(e) =>
                setEditing((prev) => ({
                  ...prev,
                  is_active: e.target.checked,
                }))
              }
            />
            Active on home
          </label>
          <div className="flex gap-3">
            <button
              type="submit"
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-amber-500 text-black font-black"
            >
              <Save size={16} />
              Save
            </button>
            <button
              type="button"
              onClick={() => setEditing(null)}
              className="px-5 py-2.5 rounded-xl bg-white/5 font-bold"
            >
              Cancel
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
