"use client";
import { CdnImg } from "@/components/CdnImg";
import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  deleteSuGameCategory,
  deleteSuGameItem,
  setSuGameCategoryOrder,
  setSuGameItemOrder,
  uploadSuGameImage,
  upsertSuGameCategory,
  upsertSuGameItem,
  type SuGameCategory,
  type SuGameItem,
  type SuGameOption,
} from "@/app/settings/su-games/actions";
import { ArrowDown, ArrowUp, Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
export function SuGamesManager({
  categories: initialCategories,
  items: initialItems,
  games,
}: {
  categories: SuGameCategory[];
  items: SuGameItem[];
  games: SuGameOption[];
}) {
  const router = useRouter();
  const [categories, setCategories] = useState(initialCategories);
  const [items, setItems] = useState(initialItems);
  const [selectedId, setSelectedId] = useState<string | null>(initialCategories[0]?.id ?? null);
  const [editingCat, setEditingCat] = useState<Partial<SuGameCategory> | null>(null);
  const [editingItem, setEditingItem] = useState<Partial<SuGameItem> | null>(null);
  const [pending, startTransition] = useTransition();
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    setCategories(initialCategories);
    setItems(initialItems);
    setSelectedId((prev) =>
      prev && initialCategories.some((c) => c.id === prev)
        ? prev
        : (initialCategories[0]?.id ?? null),
    );
  }, [initialCategories, initialItems]);
  const selected = categories.find((c) => c.id === selectedId) ?? null;
  const categoryItems = useMemo(
    () => items.filter((i) => i.category_id === selectedId),
    [items, selectedId],
  );
  const usedH5Slugs = useMemo(
    () =>
      new Set(
        categoryItems
          .filter((i) => i.kind === "h5" && i.game_slug)
          .map((i) => i.game_slug as string),
      ),
    [categoryItems],
  );
  const hasRupee = categoryItems.some((i) => i.kind === "rupee");
  const availableGames = games.filter((g) => !usedH5Slugs.has(g.slug));
  async function moveCategory(id: string, dir: -1 | 1) {
    const idx = categories.findIndex((c) => c.id === id);
    const swap = idx + dir;
    if (idx < 0 || swap < 0 || swap >= categories.length) return;
    const next = [...categories];
    const tmp = next[idx];
    next[idx] = next[swap];
    next[swap] = tmp;
    setCategories(next);
    startTransition(async () => {
      const res = await setSuGameCategoryOrder(next.map((c) => c.id));
      if (!res.success) {
        alert(res.error);
        setCategories(initialCategories);
      } else {
        router.refresh();
      }
    });
  }
  async function moveItem(id: string, dir: -1 | 1) {
    const idx = categoryItems.findIndex((i) => i.id === id);
    const swap = idx + dir;
    if (idx < 0 || swap < 0 || swap >= categoryItems.length) return;
    const nextCat = [...categoryItems];
    const tmp = nextCat[idx];
    nextCat[idx] = nextCat[swap];
    nextCat[swap] = tmp;
    const others = items.filter((i) => i.category_id !== selectedId);
    setItems([...others, ...nextCat]);
    startTransition(async () => {
      const res = await setSuGameItemOrder(nextCat.map((i) => i.id));
      if (!res.success) {
        alert(res.error);
        setItems(initialItems);
      } else {
        router.refresh();
      }
    });
  }
  async function toggleCategory(cat: SuGameCategory) {
    const res = await upsertSuGameCategory({
      id: cat.id,
      name: cat.name,
      sort_order: cat.sort_order,
      is_active: !cat.is_active,
    });
    if (!res.success) alert(res.error);
    else router.refresh();
  }
  async function toggleItem(item: SuGameItem) {
    const res = await upsertSuGameItem({
      id: item.id,
      category_id: item.category_id,
      kind: item.kind,
      game_slug: item.game_slug,
      title: item.title,
      image_url: item.image_url,
      sort_order: item.sort_order,
      is_active: !item.is_active,
    });
    if (!res.success) alert(res.error);
    else router.refresh();
  }
  async function saveCategory(e: React.FormEvent) {
    e.preventDefault();
    if (!editingCat?.name?.trim()) return;
    const res = await upsertSuGameCategory({
      id: editingCat.id,
      name: editingCat.name,
      sort_order: editingCat.sort_order ?? categories.length,
      is_active: editingCat.is_active ?? true,
    });
    if (!res.success) {
      alert(res.error);
      return;
    }
    setEditingCat(null);
    router.refresh();
  }
  async function saveItem(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedId || !editingItem?.kind) return;
    const res = await upsertSuGameItem({
      id: editingItem.id,
      category_id: selectedId,
      kind: editingItem.kind,
      game_slug: editingItem.game_slug,
      title: editingItem.title,
      image_url: editingItem.image_url,
      sort_order: editingItem.sort_order ?? categoryItems.length,
      is_active: editingItem.is_active ?? true,
    });
    if (!res.success) {
      alert(res.error);
      return;
    }
    setEditingItem(null);
    router.refresh();
  }
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !editingItem) return;
    setUploading(true);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadSuGameImage(fd);
    if (res.success && res.url) {
      setEditingItem((prev) => ({ ...prev, image_url: res.url }));
    } else {
      alert(res.error ?? "Upload failed");
    }
    setUploading(false);
    e.target.value = "";
  }
  async function handleDeleteCategory(id: string) {
    if (!confirm("Delete this category and its games from SU?")) return;
    const res = await deleteSuGameCategory(id);
    if (!res.success) alert(res.error);
    else {
      if (selectedId === id) setSelectedId(categories.find((c) => c.id !== id)?.id ?? null);
      router.refresh();
    }
  }
  async function handleDeleteItem(id: string) {
    if (!confirm("Remove this game from the category?")) return;
    const res = await deleteSuGameItem(id);
    if (!res.success) alert(res.error);
    else router.refresh();
  }
  return (
    <div className="grid lg:grid-cols-[280px_1fr] gap-6">
      <section className="glass-card p-4 space-y-3">
        <div className="flex items-center justify-between gap-2">
          <h2 className="text-sm font-black uppercase tracking-widest text-white/50">Categories</h2>
          <button
            type="button"
            onClick={() =>
              setEditingCat({
                name: "",
                sort_order: categories.length,
                is_active: true,
              })
            }
            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-amber-500/20 border border-amber-500/30 text-amber-200 text-xs font-bold"
          >
            <Plus size={14} />
            Add
          </button>
        </div>
        <p className="text-[11px] text-white/40">Left-side labels on SU. Order = top → bottom.</p>
        <div className="space-y-2">
          {categories.map((cat, index) => (
            <div
              key={cat.id}
              className={`rounded-xl border p-3 ${
                selectedId === cat.id
                  ? "border-amber-400/50 bg-amber-500/10"
                  : "border-white/10 bg-black/20"
              }`}
            >
              <button
                type="button"
                onClick={() => setSelectedId(cat.id)}
                className="w-full text-left font-bold"
              >
                {cat.name}
              </button>
              <div className="mt-2 flex items-center gap-1">
                <button
                  type="button"
                  disabled={pending || index === 0}
                  onClick={() => moveCategory(cat.id, -1)}
                  className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30"
                >
                  <ArrowUp size={12} />
                </button>
                <button
                  type="button"
                  disabled={pending || index === categories.length - 1}
                  onClick={() => moveCategory(cat.id, 1)}
                  className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30"
                >
                  <ArrowDown size={12} />
                </button>
                <button
                  type="button"
                  onClick={() => toggleCategory(cat)}
                  className={`ml-1 px-2 py-1 rounded-lg text-[10px] font-black uppercase tracking-widest ${
                    cat.is_active
                      ? "bg-emerald-500/20 text-emerald-300"
                      : "bg-white/10 text-white/40"
                  }`}
                >
                  {cat.is_active ? "On" : "Off"}
                </button>
                <button
                  type="button"
                  onClick={() => setEditingCat(cat)}
                  className="ml-auto px-2 py-1 rounded-lg bg-white/5 text-[10px] font-bold"
                >
                  Edit
                </button>
                <button
                  type="button"
                  onClick={() => handleDeleteCategory(cat.id)}
                  className="p-1.5 rounded-lg bg-red-500/10 text-red-300"
                >
                  <Trash2 size={12} />
                </button>
              </div>
            </div>
          ))}
          {categories.length === 0 && (
            <p className="text-sm text-white/40 py-6 text-center">
              No categories yet. Add Hot / Slots / Cards etc.
            </p>
          )}
        </div>

        {editingCat && (
          <form
            onSubmit={saveCategory}
            className="mt-3 p-3 rounded-xl border border-amber-500/20 bg-black/30 space-y-3"
          >
            <label className="block space-y-1">
              <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                Category name
              </span>
              <input
                className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                value={editingCat.name ?? ""}
                onChange={(e) => setEditingCat((prev) => ({ ...prev, name: e.target.value }))}
                placeholder="Hot"
              />
            </label>
            <label className="inline-flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={editingCat.is_active ?? true}
                onChange={(e) =>
                  setEditingCat((prev) => ({
                    ...prev,
                    is_active: e.target.checked,
                  }))
                }
              />
              Show on SU
            </label>
            <div className="flex gap-2">
              <button
                type="submit"
                className="inline-flex items-center gap-1 px-3 py-2 rounded-xl bg-amber-500 text-black text-xs font-black"
              >
                <Save size={14} />
                Save
              </button>
              <button
                type="button"
                onClick={() => setEditingCat(null)}
                className="px-3 py-2 rounded-xl bg-white/5 text-xs font-bold"
              >
                Cancel
              </button>
            </div>
          </form>
        )}
      </section>

      <section className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-xl font-black">
              {selected ? `${selected.name} games` : "Select a category"}
            </h2>
            <p className="text-sm text-white/40">
              Toggle Off to hide a game from SU. Order = left → right, top → bottom.
            </p>
          </div>
          {selected && (
            <div className="flex gap-2">
              <button
                type="button"
                disabled={availableGames.length === 0}
                onClick={() => {
                  const g = availableGames[0];
                  setEditingItem({
                    category_id: selected.id,
                    kind: "h5",
                    game_slug: g?.slug ?? "",
                    title: g?.name ?? "",
                    image_url: g?.icon_url ?? "",
                    sort_order: categoryItems.length,
                    is_active: true,
                  });
                }}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-violet-500/20 border border-violet-500/30 text-violet-200 text-sm font-bold disabled:opacity-40"
              >
                <Plus size={16} />
                Add H5 game
              </button>
              <button
                type="button"
                disabled={hasRupee}
                onClick={() =>
                  setEditingItem({
                    category_id: selected.id,
                    kind: "rupee",
                    game_slug: null,
                    title: "Lucky Offer",
                    image_url: "",
                    sort_order: categoryItems.length,
                    is_active: true,
                  })
                }
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-500/20 border border-emerald-500/30 text-emerald-200 text-sm font-bold disabled:opacity-40"
              >
                <Plus size={16} />
                Add Lucky Offer
              </button>
            </div>
          )}
        </div>

        {!selected && (
          <div className="glass-card p-10 text-center text-white/40">
            Create or select a category on the left.
          </div>
        )}

        {selected && (
          <div className="glass-card overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-[10px] uppercase tracking-widest text-white/30 border-b border-white/10">
                  <th className="p-4">Order</th>
                  <th className="p-4">Icon</th>
                  <th className="p-4">Game</th>
                  <th className="p-4">Type</th>
                  <th className="p-4">SU</th>
                  <th className="p-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {categoryItems.map((item, index) => (
                  <tr key={item.id} className="border-t border-white/5">
                    <td className="p-4">
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          disabled={pending || index === 0}
                          onClick={() => moveItem(item.id, -1)}
                          className="p-2 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30"
                        >
                          <ArrowUp size={14} />
                        </button>
                        <button
                          type="button"
                          disabled={pending || index === categoryItems.length - 1}
                          onClick={() => moveItem(item.id, 1)}
                          className="p-2 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30"
                        >
                          <ArrowDown size={14} />
                        </button>
                      </div>
                    </td>
                    <td className="p-4">
                      {item.image_url ? (
                        <CdnImg
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
                      <p className="text-xs text-white/40">
                        {item.kind === "rupee" ? "lucky_offer" : item.game_slug}
                      </p>
                    </td>
                    <td className="p-4 text-xs uppercase tracking-widest text-white/40">
                      {item.kind === "rupee" ? "Lucky Offer" : "H5"}
                    </td>
                    <td className="p-4">
                      <button
                        type="button"
                        onClick={() => toggleItem(item)}
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
                        onClick={() => setEditingItem(item)}
                        className="px-3 py-1.5 rounded-lg bg-white/5 text-xs font-bold hover:bg-white/10"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeleteItem(item.id)}
                        className="px-3 py-1.5 rounded-lg bg-red-500/10 text-red-300 text-xs font-bold hover:bg-red-500/20"
                      >
                        <Trash2 size={14} className="inline" />
                      </button>
                    </td>
                  </tr>
                ))}
                {categoryItems.length === 0 && (
                  <tr>
                    <td colSpan={6} className="p-8 text-center text-white/40">
                      No games in this category yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}

        {editingItem && selected && (
          <form onSubmit={saveItem} className="glass-card p-6 space-y-4 border border-amber-500/20">
            <h3 className="text-lg font-black">
              {editingItem.id ? "Edit SU game" : "Add SU game"}
            </h3>
            <div className="grid sm:grid-cols-2 gap-4">
              <label className="block space-y-1">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Type
                </span>
                <select
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                  value={editingItem.kind ?? "h5"}
                  disabled={!!editingItem.id}
                  onChange={(e) => {
                    const kind = e.target.value === "rupee" ? "rupee" : "h5";
                    const g = availableGames[0];
                    setEditingItem((prev) => ({
                      ...prev,
                      kind,
                      game_slug: kind === "h5" ? (g?.slug ?? "") : null,
                      title:
                        kind === "rupee"
                          ? prev?.title || "Lucky Offer"
                          : prev?.title || g?.name || "",
                      image_url:
                        kind === "h5"
                          ? prev?.image_url || g?.icon_url || ""
                          : prev?.image_url || "",
                    }));
                  }}
                >
                  <option value="h5">H5 game</option>
                  <option value="rupee" disabled={hasRupee && editingItem.kind !== "rupee"}>
                    Lucky Offer (Rupee)
                  </option>
                </select>
              </label>
              {editingItem.kind !== "rupee" && (
                <label className="block space-y-1">
                  <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                    Game
                  </span>
                  <select
                    className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                    value={editingItem.game_slug ?? ""}
                    disabled={!!editingItem.id}
                    onChange={(e) => {
                      const g = games.find((x) => x.slug === e.target.value);
                      setEditingItem((prev) => ({
                        ...prev,
                        game_slug: e.target.value,
                        title: prev?.title || g?.name || "",
                        image_url: prev?.image_url || g?.icon_url || "",
                      }));
                    }}
                  >
                    <option value="">Select…</option>
                    {(editingItem.id ? games : availableGames).map((g) => (
                      <option key={g.slug} value={g.slug}>
                        {g.name} ({g.slug})
                      </option>
                    ))}
                  </select>
                </label>
              )}
              <label className="block space-y-1 sm:col-span-2">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Display title
                </span>
                <input
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                  value={editingItem.title ?? ""}
                  onChange={(e) => setEditingItem((prev) => ({ ...prev, title: e.target.value }))}
                />
              </label>
            </div>
            <div className="flex flex-wrap items-end gap-4">
              <label className="block space-y-1 flex-1 min-w-[220px]">
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  Icon URL
                </span>
                <input
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2"
                  value={editingItem.image_url ?? ""}
                  onChange={(e) =>
                    setEditingItem((prev) => ({
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
              {editingItem.image_url ? (
                <CdnImg
                  src={editingItem.image_url}
                  alt=""
                  className="w-14 h-14 rounded-2xl object-cover border border-white/10"
                />
              ) : null}
            </div>
            <label className="inline-flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={editingItem.is_active ?? true}
                onChange={(e) =>
                  setEditingItem((prev) => ({
                    ...prev,
                    is_active: e.target.checked,
                  }))
                }
              />
              Show on SU
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
                onClick={() => setEditingItem(null)}
                className="px-5 py-2.5 rounded-xl bg-white/5 font-bold"
              >
                Cancel
              </button>
            </div>
          </form>
        )}
      </section>
    </div>
  );
}
