"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  HOME_TOP_BANNER_HEIGHT_DEFAULT,
  HOME_TOP_BANNER_HEIGHT_MAX,
  HOME_TOP_BANNER_HEIGHT_MIN,
} from "@/app/settings/home-banners/constants";
import {
  deleteHomeBanner,
  saveHomeTopBannerHeight,
  uploadHomeBannerImage,
  upsertHomeBanner,
  type BannerPartyEventOption,
  type HomeBannerPlacement,
  type HomeBannerRow,
} from "@/app/settings/home-banners/actions";
import { promoBannerSizeIssue, promoBannerSpecForPlacement } from "@/lib/promoBannerSize";
import { Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
function readImageSize(file: File): Promise<{
  width: number;
  height: number;
}> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const width = img.naturalWidth;
      const height = img.naturalHeight;
      URL.revokeObjectURL(url);
      resolve({ width, height });
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not read image dimensions"));
    };
    img.src = url;
  });
}
export function HomeBannersManager({
  items,
  placement = "top",
  partyEvents = [],
  initialDisplayHeight = HOME_TOP_BANNER_HEIGHT_DEFAULT,
}: {
  items: HomeBannerRow[];
  placement?: HomeBannerPlacement;
  partyEvents?: BannerPartyEventOption[];
  initialDisplayHeight?: number;
}) {
  const router = useRouter();
  const [editing, setEditing] = useState<Partial<HomeBannerRow> | null>(null);
  const [saving, setSaving] = useState(false);
  const [savingHeight, setSavingHeight] = useState(false);
  const [displayHeight, setDisplayHeight] = useState(initialDisplayHeight);
  const [heightMessage, setHeightMessage] = useState("");
  const [uploading, setUploading] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [sizeWarning, setSizeWarning] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const isMid = placement === "after_rooms";
  const isProfile = placement === "profile";
  const isTop = placement === "top";
  const sizeSpec = promoBannerSpecForPlacement(placement);
  function startNew() {
    setSizeWarning(null);
    setEditing({
      image_url: "",
      link_url: "",
      room_number: null,
      party_event_id: null,
      priority: (items[0]?.priority ?? 0) + 1,
      is_active: true,
      placement,
    });
  }
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !editing) return;
    setUploading(true);
    setSizeWarning(null);
    try {
      const { width, height } = await readImageSize(file);
      const issue = promoBannerSizeIssue(width, height, placement);
      if (issue) {
        setSizeWarning(issue);
        alert(`${issue}\n\nPlease export at ${sizeSpec.label} and upload again.`);
        setUploading(false);
        e.target.value = "";
        return;
      }
    } catch {}
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadHomeBannerImage(fd);
    if (res.success && res.url) {
      setEditing((prev) => ({ ...prev, image_url: res.url }));
      setSizeWarning(null);
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
    }
    setUploading(false);
    e.target.value = "";
  }
  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!editing?.image_url?.trim()) {
      alert("Please upload a banner image first");
      return;
    }
    setSaving(true);
    const res = await upsertHomeBanner({
      id: editing.id,
      image_url: editing.image_url,
      link_url: editing.link_url ?? null,
      room_number: editing.room_number ?? null,
      party_event_id: editing.party_event_id ?? null,
      priority: Number(editing.priority ?? 0),
      is_active: editing.is_active ?? true,
      placement,
    });
    setSaving(false);
    if (!res.success) {
      alert(res.error ?? "Save failed");
      return;
    }
    setEditing(null);
    setSizeWarning(null);
    router.refresh();
  }
  async function handleDelete(id: string) {
    if (!confirm("Delete this home banner?")) return;
    setDeletingId(id);
    const res = await deleteHomeBanner(id);
    setDeletingId(null);
    if (!res.success) {
      alert(res.error ?? "Delete failed");
      return;
    }
    if (editing?.id === id) setEditing(null);
    router.refresh();
  }
  async function handleSaveHeight(e: React.FormEvent) {
    e.preventDefault();
    setSavingHeight(true);
    setHeightMessage("");
    const res = await saveHomeTopBannerHeight(displayHeight);
    setSavingHeight(false);
    if (!res.success) {
      setHeightMessage(res.error ?? "Save failed");
      return;
    }
    setDisplayHeight(res.height);
    setHeightMessage(`Saved. App banner height is now ${res.height}px.`);
    router.refresh();
  }
  return (
    <div className="space-y-8">
      {isTop && (
        <form
          onSubmit={handleSaveHeight}
          className="glass-card border border-cyan-500/20 p-6 space-y-4"
        >
          <div>
            <h2 className="text-lg font-black">Display height</h2>
            <p className="text-sm text-white/50 mt-1">
              Home Hot top banner height in the app. Drag to the size you want, then save. Does not
              change upload image size.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-4">
            <input
              type="range"
              min={HOME_TOP_BANNER_HEIGHT_MIN}
              max={HOME_TOP_BANNER_HEIGHT_MAX}
              step={4}
              value={displayHeight}
              onChange={(e) => setDisplayHeight(Number(e.target.value))}
              className="flex-1 min-w-[200px] accent-amber-400"
            />
            <label className="inline-flex items-center gap-2 text-sm font-bold">
              <input
                type="number"
                min={HOME_TOP_BANNER_HEIGHT_MIN}
                max={HOME_TOP_BANNER_HEIGHT_MAX}
                value={displayHeight}
                onChange={(e) =>
                  setDisplayHeight(Number(e.target.value || HOME_TOP_BANNER_HEIGHT_DEFAULT))
                }
                className="w-24 bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-center"
              />
              px
            </label>
            <button
              type="submit"
              disabled={savingHeight}
              className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-amber-500 text-black font-black text-sm disabled:opacity-50"
            >
              {savingHeight ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
              Save height
            </button>
          </div>
          <div
            className="rounded-2xl bg-black/30 border border-white/10 overflow-hidden"
            style={{ height: Math.round(displayHeight * 0.55) }}
          >
            <div className="h-full w-full bg-gradient-to-r from-cyan-500/30 via-amber-400/25 to-fuchsia-500/30 flex items-center justify-center text-xs font-bold text-white/70">
              Preview {displayHeight}px
            </div>
          </div>
          {heightMessage && <p className="text-sm text-emerald-300">{heightMessage}</p>}
        </form>
      )}

      <div className="flex items-center justify-between gap-4 flex-wrap">
        <p className="text-sm text-white/50 max-w-2xl">
          {isProfile
            ? `Profile tab promo carousel. Design at ${sizeSpec.label}.`
            : isMid
              ? `Shown after the first 2 room cards. Design at ${sizeSpec.label}.`
              : `Top auto-scrolling Hot banners. Design at ${sizeSpec.label}. Higher priority shows first.`}
        </p>
        <button
          type="button"
          onClick={startNew}
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-amber-500 text-black font-bold text-sm hover:bg-amber-400 transition-colors"
        >
          <Plus size={16} />
          Add banner
        </button>
      </div>

      {editing && (
        <form onSubmit={handleSave} className="glass-card border border-amber-500/20 p-6 space-y-5">
          <h2 className="text-lg font-bold text-white">
            {editing.id ? "Edit banner" : "New banner"}
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-3">
              <div
                className={`${sizeSpec.aspectClass} rounded-2xl overflow-hidden bg-black/40 border border-white/10 flex items-center justify-center`}
              >
                {editing.image_url ? (
                  <img
                    src={editing.image_url}
                    alt="Banner preview"
                    className="w-full h-full object-contain"
                  />
                ) : (
                  <span className="text-white/30 text-sm text-center px-4">
                    No image yet — upload {sizeSpec.label}
                  </span>
                )}
              </div>
              {sizeWarning && <p className="text-xs text-red-300 font-medium">{sizeWarning}</p>}
              <input
                ref={fileRef}
                type="file"
                accept="image/png,image/jpeg,image/webp,image/jpg"
                className="hidden"
                onChange={handleUpload}
              />
              <button
                type="button"
                disabled={uploading}
                onClick={() => fileRef.current?.click()}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border border-white/15 text-sm text-white/80 hover:bg-white/5 disabled:opacity-50"
              >
                {uploading ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
                Upload {sizeSpec.label}
              </button>
            </div>

            <div className="space-y-4">
              {isTop && (
                <label className="block space-y-1.5">
                  <span className="text-xs uppercase tracking-widest text-white/40 font-bold">
                    Linked event (optional)
                  </span>
                  <select
                    value={editing.party_event_id ?? ""}
                    onChange={(e) =>
                      setEditing((p) => ({
                        ...p,
                        party_event_id: e.target.value || null,
                        room_number: e.target.value ? null : p?.room_number,
                      }))
                    }
                    className="w-full rounded-xl bg-black/30 border border-white/10 px-3 py-2.5 text-sm text-white"
                  >
                    <option value="">None — no event tap</option>
                    {partyEvents.map((pe) => (
                      <option key={pe.id} value={pe.id}>
                        {pe.title}
                        {pe.is_active === false ? " (inactive)" : ""}
                      </option>
                    ))}
                  </select>
                  <span className="text-xs text-white/35">
                    Tap opens this party event. Leave empty if you want a room tap instead.
                  </span>
                </label>
              )}

              {(isMid || isTop) && (
                <label className="block space-y-1.5">
                  <span className="text-xs uppercase tracking-widest text-white/40 font-bold">
                    Room number (optional)
                  </span>
                  <input
                    type="number"
                    inputMode="numeric"
                    min={1}
                    value={editing.room_number ?? ""}
                    onChange={(e) => {
                      const raw = e.target.value.trim();
                      setEditing((p) => ({
                        ...p,
                        room_number: raw === "" ? null : Number(raw),
                        party_event_id: raw ? null : p?.party_event_id,
                      }));
                    }}
                    className="w-full rounded-xl bg-black/30 border border-white/10 px-3 py-2.5 text-sm text-white"
                    placeholder="e.g. 100201"
                  />
                  <span className="text-xs text-white/35">
                    Public room ID. Tap opens that room in the app.
                    {isTop ? " If set, this is used instead of the event." : ""}
                  </span>
                </label>
              )}

              <label className="block space-y-1.5">
                <span className="text-xs uppercase tracking-widest text-white/40 font-bold">
                  Link URL (optional)
                </span>
                <input
                  value={editing.link_url ?? ""}
                  onChange={(e) => setEditing((p) => ({ ...p, link_url: e.target.value }))}
                  className="w-full rounded-xl bg-black/30 border border-white/10 px-3 py-2.5 text-sm text-white"
                  placeholder="https://..."
                />
              </label>

              <label className="block space-y-1.5">
                <span className="text-xs uppercase tracking-widest text-white/40 font-bold">
                  Priority
                </span>
                <input
                  type="number"
                  value={editing.priority ?? 0}
                  onChange={(e) =>
                    setEditing((p) => ({
                      ...p,
                      priority: Number(e.target.value),
                    }))
                  }
                  className="w-full rounded-xl bg-black/30 border border-white/10 px-3 py-2.5 text-sm text-white"
                />
              </label>

              <label className="inline-flex items-center gap-2 text-sm text-white/70">
                <input
                  type="checkbox"
                  checked={editing.is_active ?? true}
                  onChange={(e) => setEditing((p) => ({ ...p, is_active: e.target.checked }))}
                  className="rounded border-white/20"
                />
                Active (show in app)
              </label>
            </div>
          </div>

          <div className="flex items-center gap-3 pt-2">
            <button
              type="submit"
              disabled={saving}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-amber-500 text-black font-bold text-sm disabled:opacity-50"
            >
              {saving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
              Save
            </button>
            <button
              type="button"
              onClick={() => {
                setEditing(null);
                setSizeWarning(null);
              }}
              className="px-4 py-2.5 rounded-xl text-sm text-white/50 hover:text-white"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
        {items.map((banner) => (
          <div key={banner.id} className="glass-card border border-white/10 overflow-hidden">
            <div className={`${sizeSpec.aspectClass} bg-black/40`}>
              <img
                src={banner.image_url}
                alt={`Banner priority ${banner.priority}`}
                className="w-full h-full object-contain"
              />
            </div>
            <div className="p-4 space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-bold text-white text-sm">Banner #{banner.priority}</p>
                  <p className="text-xs text-white/40 mt-1">
                    Priority {banner.priority} ·{" "}
                    {banner.is_active ? (
                      <span className="text-emerald-400">Active</span>
                    ) : (
                      <span className="text-red-300">Inactive</span>
                    )}
                    {(isMid || isTop) && banner.room_number != null ? (
                      <> · Room {banner.room_number}</>
                    ) : null}
                    {isTop && !banner.room_number && banner.party_event_id
                      ? (() => {
                          const pe = partyEvents.find((e) => e.id === banner.party_event_id);
                          return <> · Event {pe?.title ?? banner.party_event_id.slice(0, 8)}</>;
                        })()
                      : null}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setSizeWarning(null);
                    setEditing({ ...banner, placement });
                  }}
                  className="px-3 py-1.5 rounded-lg text-xs font-bold bg-white/10 hover:bg-white/15 text-white"
                >
                  Edit
                </button>
                <button
                  type="button"
                  disabled={deletingId === banner.id}
                  onClick={() => handleDelete(banner.id)}
                  className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-bold text-red-300 hover:bg-red-500/10 disabled:opacity-50"
                >
                  {deletingId === banner.id ? (
                    <Loader2 size={12} className="animate-spin" />
                  ) : (
                    <Trash2 size={12} />
                  )}
                  Delete
                </button>
              </div>
            </div>
          </div>
        ))}

        {items.length === 0 && !editing && (
          <div className="col-span-full glass-card border border-dashed border-white/15 p-10 text-center text-white/40 text-sm">
            {isProfile
              ? `No profile banners yet. Add a ${sizeSpec.label} image.`
              : isMid
                ? `No mid-feed banners yet. Add a ${sizeSpec.label} image.`
                : `No home banners yet. Add a ${sizeSpec.label} image.`}
          </div>
        )}
      </div>
    </div>
  );
}
