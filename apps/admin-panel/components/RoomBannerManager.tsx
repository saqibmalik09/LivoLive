"use client";
import { useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  searchAdminRooms,
  setRoomPinned,
  updateRoomBanner,
  updateRoomLiveBackground,
  uploadRoomBannerImage,
  type AdminRoomRow,
} from "@/app/settings/rooms/actions";
import { Home, Loader2, Pin, PinOff, Save, Search, Upload } from "lucide-react";
const inputClass =
  "w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder:text-white/30 focus:outline-none focus:border-amber-500/50";
const btnClass =
  "inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-amber-500 text-black font-bold text-sm hover:bg-amber-400 disabled:opacity-50 transition-colors";
export function RoomBannerManager({ initialRooms }: { initialRooms: AdminRoomRow[] }) {
  const router = useRouter();
  const [rooms, setRooms] = useState(initialRooms);
  const [query, setQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(initialRooms[0]?.id ?? null);
  const [bannerUrl, setBannerUrl] = useState(initialRooms[0]?.imageUrl ?? "");
  const [bgUrl, setBgUrl] = useState(initialRooms[0]?.backgroundUrl ?? "");
  const [uploading, setUploading] = useState<"banner" | "bg" | null>(null);
  const [pending, startTransition] = useTransition();
  const bannerInputRef = useRef<HTMLInputElement>(null);
  const bgInputRef = useRef<HTMLInputElement>(null);
  const selected = useMemo(
    () => rooms.find((r) => r.id === selectedId) ?? null,
    [rooms, selectedId],
  );
  function selectRoom(room: AdminRoomRow) {
    setSelectedId(room.id);
    setBannerUrl(room.imageUrl ?? "");
    setBgUrl(room.backgroundUrl ?? "");
  }
  async function handleSearch(e: React.FormEvent) {
    e.preventDefault();
    startTransition(async () => {
      const rows = await searchAdminRooms(query);
      setRooms(rows);
      if (rows.length > 0) {
        selectRoom(rows[0]);
      }
    });
  }
  async function handleUpload(file: File | undefined, kind: "banner" | "bg") {
    if (!file) return;
    setUploading(kind);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadRoomBannerImage(fd);
    setUploading(null);
    if (!res.success || !res.url) {
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
      return;
    }
    if (kind === "banner") setBannerUrl(res.url);
    else setBgUrl(res.url);
  }
  async function saveBanner() {
    if (!selectedId) return;
    startTransition(async () => {
      const res = await updateRoomBanner(selectedId, bannerUrl || null);
      if (!res.success) {
        alert(res.error ?? "Save failed");
        return;
      }
      setRooms((prev) =>
        prev.map((r) => (r.id === selectedId ? { ...r, imageUrl: bannerUrl || null } : r)),
      );
      router.refresh();
    });
  }
  async function saveBackground() {
    if (!selectedId) return;
    startTransition(async () => {
      const res = await updateRoomLiveBackground(selectedId, bgUrl || null);
      if (!res.success) {
        alert(res.error ?? "Save failed");
        return;
      }
      setRooms((prev) =>
        prev.map((r) => (r.id === selectedId ? { ...r, backgroundUrl: bgUrl || null } : r)),
      );
      router.refresh();
    });
  }
  // One control, and one featured room. Picking a numbered slot meant knowing
  // which card on the home screen each number drew, and the home screen now
  // shows a single full-width card, so featuring a room replaces the current
  // one rather than filling a second position.
  async function togglePinned(pinned: boolean) {
    if (!selected) return;
    startTransition(async () => {
      const res = await setRoomPinned(selected.id, pinned);
      if (!res.success) {
        alert(res.error ?? (pinned ? "Pin failed" : "Unpin failed"));
        return;
      }
      const slot = pinned ? Number(res.pinOrder ?? 0) : 0;
      setRooms((prev) =>
        prev.map((r) => {
          if (r.id === selected.id) {
            return { ...r, isPinned: pinned, pinOrder: slot };
          }
          // Only one room is featured, so everything else is now unpinned.
          return pinned && r.isPinned ? { ...r, isPinned: false, pinOrder: 0 } : r;
        }),
      );
      router.refresh();
    });
  }
  return (
    <div className="grid grid-cols-1 xl:grid-cols-5 gap-8">
      <div className="xl:col-span-2 space-y-4">
        <form onSubmit={handleSearch} className="flex gap-2">
          <input
            className={inputClass}
            placeholder="Search room title or ID…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <button type="submit" className={btnClass} disabled={pending}>
            {pending ? <Loader2 size={16} className="animate-spin" /> : <Search size={16} />}
          </button>
        </form>

        <div className="glass-card max-h-[560px] overflow-y-auto divide-y divide-white/5">
          {rooms.length === 0 ? (
            <p className="p-6 text-sm text-white/40">No rooms found.</p>
          ) : (
            rooms.map((room) => (
              <button
                key={room.id}
                type="button"
                onClick={() => selectRoom(room)}
                className={`w-full text-left p-4 flex gap-3 hover:bg-white/5 transition-colors ${selectedId === room.id ? "bg-amber-500/10" : ""}`}
              >
                <div className="w-14 h-14 rounded-xl overflow-hidden bg-black/40 border border-white/10 shrink-0">
                  {room.imageUrl ? (
                    <img src={room.imageUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-white/20">
                      <Home size={20} />
                    </div>
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-bold text-white truncate flex items-center gap-2">
                    {room.title}
                    {room.isPinned ? (
                      <span className="shrink-0 text-[9px] font-black uppercase tracking-widest text-amber-300 bg-amber-500/15 border border-amber-400/30 px-1.5 py-0.5 rounded">
                        Featured
                      </span>
                    ) : null}
                  </p>
                  <p className="text-[11px] text-white/40 truncate">
                    Host: {room.hostUsername ?? "—"}
                    {room.hostShortId ? ` · ID ${room.hostShortId}` : ""}
                  </p>
                  <p className="text-[10px] text-white/25 font-mono truncate">
                    ID {room.shortId ?? room.hostShortId ?? room.id.slice(0, 8).toUpperCase()} ·{" "}
                    {room.onlineUsersCount} online
                  </p>
                </div>
              </button>
            ))
          )}
        </div>
      </div>

      <div className="xl:col-span-3 glass-card space-y-6">
        {!selected ? (
          <p className="text-white/40 text-sm">Select a room to edit banner.</p>
        ) : (
          <>
            <div className="space-y-3">
              <div>
                <h2 className="text-xl font-bold text-white">{selected.title}</h2>
                <p className="text-xs text-white/40 mt-1">
                  Room ID {selected.shortId ?? selected.hostShortId ?? "—"}
                </p>
                <p className="text-[10px] text-white/25 font-mono mt-1">{selected.id}</p>
              </div>
              <div>
                <p className="text-[10px] font-black uppercase tracking-widest text-amber-300 mb-2">
                  Feature on home
                </p>
                <button
                  type="button"
                  disabled={pending}
                  onClick={() => togglePinned(!selected.isPinned)}
                  className={`inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-black text-sm disabled:opacity-50 transition-colors ${
                    selected.isPinned
                      ? "bg-amber-500 text-black hover:bg-amber-400"
                      : "bg-white/10 text-white border border-white/15 hover:bg-white/15"
                  }`}
                >
                  {pending ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : selected.isPinned ? (
                    <>
                      <PinOff size={14} />
                      Unpin from home
                    </>
                  ) : (
                    <>
                      <Pin size={14} />
                      Pin to home
                    </>
                  )}
                </button>
                <p className="text-[11px] text-white/40 mt-2">
                  {selected.isPinned
                    ? "Featured on the home screen above the room list."
                    : "Shows this room on the home screen above the room list. Featuring a room replaces the one featured now."}
                </p>
              </div>
            </div>

            <div className="space-y-3">
              <p className="text-[10px] font-black uppercase tracking-widest text-sky-300">
                Room card / banner
              </p>
              <div className="aspect-[16/9] max-w-md rounded-2xl overflow-hidden bg-black/40 border border-white/10">
                {bannerUrl ? (
                  <img
                    src={bannerUrl}
                    alt="Room banner preview"
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-white/30 text-sm">
                    No banner
                  </div>
                )}
              </div>
              <div className="flex gap-2 max-w-xl">
                <input
                  className={inputClass}
                  value={bannerUrl}
                  onChange={(e) => setBannerUrl(e.target.value)}
                  placeholder="Banner image URL"
                />
                <button
                  type="button"
                  className={btnClass}
                  disabled={uploading === "banner" || pending}
                  onClick={() => bannerInputRef.current?.click()}
                >
                  {uploading === "banner" ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Upload size={14} />
                  )}
                </button>
                <input
                  ref={bannerInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => handleUpload(e.target.files?.[0], "banner")}
                />
                <button type="button" className={btnClass} disabled={pending} onClick={saveBanner}>
                  {pending ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
                  Save
                </button>
              </div>
            </div>

            <div className="space-y-3 pt-2 border-t border-white/10">
              <p className="text-[10px] font-black uppercase tracking-widest text-violet-300">
                Live room background
              </p>
              <div className="flex gap-2 max-w-xl">
                <input
                  className={inputClass}
                  value={bgUrl}
                  onChange={(e) => setBgUrl(e.target.value)}
                  placeholder="Background URL (image or SVGA)"
                />
                <button
                  type="button"
                  className={btnClass}
                  disabled={uploading === "bg" || pending}
                  onClick={() => bgInputRef.current?.click()}
                >
                  {uploading === "bg" ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Upload size={14} />
                  )}
                </button>
                <input
                  ref={bgInputRef}
                  type="file"
                  accept="image/*,.svga"
                  className="hidden"
                  onChange={(e) => handleUpload(e.target.files?.[0], "bg")}
                />
                <button
                  type="button"
                  className={btnClass}
                  disabled={pending}
                  onClick={saveBackground}
                >
                  Save BG
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
