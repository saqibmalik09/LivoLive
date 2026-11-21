"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  deleteRoomSideFloatItem,
  uploadRoomSideFloatImage,
  upsertRoomSideFloatItem,
  type RoomSideFloatRow,
} from "@/app/settings/room-float/actions";
import { Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
type PartyEventOption = {
  id: string;
  title: string;
  banner_url?: string | null;
  is_active?: boolean;
};
type GameOption = {
  slug: string;
  name: string;
  icon_url?: string | null;
  is_active?: boolean;
};
export function RoomSideFloatManager({
  items,
  partyEvents,
  games,
}: {
  items: RoomSideFloatRow[];
  partyEvents: PartyEventOption[];
  games: GameOption[];
}) {
  const router = useRouter();
  const [kindFilter, setKindFilter] = useState<"all" | "event" | "game">("all");
  const [editing, setEditing] = useState<Partial<RoomSideFloatRow> | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const filtered = items.filter((i) => (kindFilter === "all" ? true : i.kind === kindFilter));
  function startNew(kind: "event" | "game") {
    setEditing({
      kind,
      title: "",
      image_url: "",
      party_event_id: null,
      game_slug: null,
      sort_order: items.filter((i) => i.kind === kind).length,
      is_active: true,
    });
  }
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !editing) return;
    setUploading(true);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadRoomSideFloatImage(fd);
    if (res.success && res.url) {
      setEditing((prev) => ({ ...prev, image_url: res.url }));
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
    }
    setUploading(false);
    e.target.value = "";
  }
  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!editing?.kind) return;
    setSaving(true);
    const res = await upsertRoomSideFloatItem({
      id: editing.id,
      kind: editing.kind,
      title: editing.title ?? "",
      image_url: editing.image_url ?? "",
      party_event_id: editing.party_event_id,
      game_slug: editing.game_slug,
      sort_order: editing.sort_order ?? 0,
      is_active: editing.is_active ?? true,
    });
    setSaving(false);
    if (res.success) {
      setEditing(null);
      router.refresh();
    } else {
      alert(res.error ?? "Save failed");
    }
  }
  async function handleDelete(id: string) {
    if (!confirm("Delete this room float image?")) return;
    setDeletingId(id);
    const res = await deleteRoomSideFloatItem(id);
    setDeletingId(null);
    if (res.success) router.refresh();
    else alert(res.error ?? "Delete failed");
  }
  function onLinkChange(value: string) {
    if (!editing) return;
    if (editing.kind === "event") {
      const pe = partyEvents.find((p) => p.id === value);
      setEditing({
        ...editing,
        party_event_id: value || null,
        title: editing.title || pe?.title || "",
        image_url: editing.image_url || pe?.banner_url || "",
      });
    } else {
      const g = games.find((x) => x.slug === value);
      setEditing({
        ...editing,
        game_slug: value || null,
        title: editing.title || g?.name || "",
        image_url: editing.image_url || g?.icon_url || "",
      });
    }
  }
  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-center gap-3">
        {(["all", "event", "game"] as const).map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => setKindFilter(k)}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest border transition-colors ${
              kindFilter === k
                ? "bg-amber-500 text-black border-amber-400"
                : "bg-black/30 text-white/50 border-white/10 hover:text-white"
            }`}
          >
            {k === "all" ? "All" : k === "event" ? "Events" : "Games"}
          </button>
        ))}
        <div className="flex-1" />
        <button
          type="button"
          onClick={() => startNew("game")}
          className="flex items-center gap-2 bg-violet-500/20 border border-violet-400/30 text-violet-200 px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest"
        >
          <Plus size={14} /> Game icon
        </button>
        <button
          type="button"
          onClick={() => startNew("event")}
          className="flex items-center gap-2 bg-sky-500/20 border border-sky-400/30 text-sky-200 px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest"
        >
          <Plus size={14} /> Event icon
        </button>
      </div>

      {editing && (
        <form onSubmit={handleSave} className="glass-card p-6 space-y-5 border border-amber-500/20">
          <div className="flex items-center justify-between gap-4">
            <h3 className="text-xl font-bold">
              {editing.id ? "Edit" : "New"} {editing.kind} float
            </h3>
            <button
              type="button"
              onClick={() => setEditing(null)}
              className="text-white/40 text-xs uppercase tracking-widest hover:text-white"
            >
              Cancel
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <label className="space-y-2 block">
              <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                Title
              </span>
              <input
                value={editing.title ?? ""}
                onChange={(e) => setEditing({ ...editing, title: e.target.value })}
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm"
                placeholder="Display name"
              />
            </label>

            <label className="space-y-2 block">
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
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm"
              />
            </label>

            <label className="space-y-2 block md:col-span-2">
              <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                {editing.kind === "event" ? "Linked party event" : "Linked game"}
              </span>
              <select
                value={
                  editing.kind === "event"
                    ? (editing.party_event_id ?? "")
                    : (editing.game_slug ?? "")
                }
                onChange={(e) => onLinkChange(e.target.value)}
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm"
              >
                <option value="">None</option>
                {editing.kind === "event"
                  ? partyEvents.map((pe) => (
                      <option key={pe.id} value={pe.id}>
                        {pe.title}
                        {pe.is_active === false ? " (inactive)" : ""}
                      </option>
                    ))
                  : games.map((g) => (
                      <option key={g.slug} value={g.slug}>
                        {g.name}
                        {g.is_active === false ? " (inactive)" : ""}
                      </option>
                    ))}
              </select>
            </label>
          </div>

          <div className="flex flex-col sm:flex-row gap-5 items-start">
            <div className="w-28 h-28 rounded-2xl overflow-hidden bg-black/50 border border-white/10 flex items-center justify-center shrink-0">
              {editing.image_url ? (
                <CdnImg src={editing.image_url} alt="" className="w-full h-full object-cover" />
              ) : (
                <span className="text-white/20 text-[10px] uppercase tracking-widest">Square</span>
              )}
            </div>
            <div className="space-y-3 flex-1">
              <p className="text-sm text-white/50">
                Upload a <strong className="text-white/80">square (murba)</strong> image for the
                room right-bottom carousel. Wide event banners will be center-cropped if used as-is.
              </p>
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
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-black uppercase tracking-widest hover:bg-white/10 disabled:opacity-50"
              >
                {uploading ? <Loader2 size={14} className="animate-spin" /> : <Upload size={14} />}
                Upload image
              </button>
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
            disabled={saving || !editing.image_url}
            className="inline-flex items-center gap-2 bg-gradient-to-r from-amber-500 to-orange-500 text-black px-6 py-3 rounded-2xl font-black uppercase tracking-widest disabled:opacity-50"
          >
            {saving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
            Save
          </button>
        </form>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
        {filtered.map((item) => (
          <div key={item.id} className="glass-card p-4 space-y-3 relative group">
            <div className="aspect-square rounded-2xl overflow-hidden bg-black/40 border border-white/5">
              <CdnImg src={item.image_url} alt={item.title} className="w-full h-full object-cover" />
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span
                  className={`text-[9px] font-black uppercase tracking-widest px-2 py-0.5 rounded-full ${
                    item.kind === "game"
                      ? "bg-violet-500/20 text-violet-300"
                      : "bg-sky-500/20 text-sky-300"
                  }`}
                >
                  {item.kind}
                </span>
                {!item.is_active && (
                  <span className="text-[9px] font-black uppercase tracking-widest text-red-300/70">
                    Off
                  </span>
                )}
              </div>
              <p className="font-bold truncate">{item.title || "Untitled"}</p>
              <p className="text-[10px] text-white/30 uppercase tracking-widest">
                Order {item.sort_order}
              </p>
            </div>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setEditing(item)}
                className="flex-1 py-2 rounded-xl bg-white/5 border border-white/10 text-[10px] font-black uppercase tracking-widest hover:bg-white/10"
              >
                Edit
              </button>
              <button
                type="button"
                disabled={deletingId === item.id}
                onClick={() => handleDelete(item.id)}
                className="px-3 py-2 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300 hover:bg-red-500/20 disabled:opacity-50"
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
        {filtered.length === 0 && (
          <p className="text-white/40 col-span-full text-sm">
            No float items yet. Add a game or event icon, or re-run the seed migration.
          </p>
        )}
      </div>
    </div>
  );
}
