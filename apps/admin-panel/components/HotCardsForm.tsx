"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  uploadHotCardMedia,
  updateHotCardsConfig,
  saveHotCardRoomTargets,
  type HotCardSlot,
  type HotCardMediaType,
} from "@/app/settings/hot-cards/actions";
import { Loader2, Upload, Save } from "lucide-react";
type Config = Record<string, string | number | null | undefined>;
interface HotCardsFormProps {
  config: Config;
  partyRoomShortId?: string | null;
  musicRoomShortId?: string | null;
}
const CAROUSEL_SLOTS: {
  slot: HotCardSlot;
  label: string;
  linkKey: string;
}[] = [
  { slot: "carousel_1", label: "Carousel slide 1 (Game King)", linkKey: "carousel_1_link" },
  { slot: "carousel_2", label: "Carousel slide 2 (CP)", linkKey: "carousel_2_link" },
  { slot: "carousel_3", label: "Carousel slide 3 (Charm)", linkKey: "carousel_3_link" },
];
export function HotCardsForm({ config, partyRoomShortId, musicRoomShortId }: HotCardsFormProps) {
  const router = useRouter();
  const [uploading, setUploading] = useState<HotCardSlot | null>(null);
  const [savingRooms, setSavingRooms] = useState(false);
  const [intervalMs, setIntervalMs] = useState(String(config.carousel_interval_ms ?? 4000));
  const [partyRoomRef, setPartyRoomRef] = useState(
    partyRoomShortId || (config.party_card_room_id as string) || "",
  );
  const [musicRoomRef, setMusicRoomRef] = useState(
    musicRoomShortId || (config.music_card_room_id as string) || "",
  );
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  async function handleUpload(
    e: React.ChangeEvent<HTMLInputElement>,
    slot: HotCardSlot,
    mediaType: HotCardMediaType,
  ) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(slot);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("slot", slot);
    formData.append("mediaType", mediaType);
    const res = await uploadHotCardMedia(formData);
    if (res.success) {
      router.refresh();
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
    }
    setUploading(null);
    e.target.value = "";
  }
  async function saveInterval(e: React.FormEvent) {
    e.preventDefault();
    const ms = parseInt(intervalMs, 10);
    const res = await updateHotCardsConfig({
      carousel_interval_ms: Number.isFinite(ms) ? ms : 4000,
    });
    if (!res.success) alert("Error: " + res.error);
    else router.refresh();
  }
  async function saveRooms(e: React.FormEvent) {
    e.preventDefault();
    setSavingRooms(true);
    const formData = new FormData();
    formData.set("party_room_ref", partyRoomRef);
    formData.set("music_room_ref", musicRoomRef);
    const res = await saveHotCardRoomTargets(formData);
    setSavingRooms(false);
    if (!res.success) {
      alert("Error: " + res.error);
      return;
    }
    if (res.partyShortId) setPartyRoomRef(res.partyShortId);
    else if (!partyRoomRef.trim()) setPartyRoomRef("");
    if (res.musicShortId) setMusicRoomRef(res.musicShortId);
    else if (!musicRoomRef.trim()) setMusicRoomRef("");
    router.refresh();
  }
  return (
    <div className="space-y-10">
      <section className="glass-card p-8 space-y-6">
        <h2 className="text-xl font-bold">Left carousel (3 slides)</h2>
        <p className="text-white/50 text-sm">
          Image, SVGA, or MP4. Links: game → Game Ranking, cp → CP Ranking, charm → Charm ranking.
        </p>
        {CAROUSEL_SLOTS.map(({ slot, label, linkKey }) => (
          <SlotField
            key={slot}
            label={label}
            url={(config[`${slot}_url`] as string) ?? ""}
            mediaType={(config[`${slot}_media_type`] as string) ?? "image"}
            link={(config[linkKey] as string) ?? ""}
            uploading={uploading === slot}
            onUploadClick={(mediaType) => {
              const input = fileRefs.current[slot];
              input?.setAttribute("data-media-type", mediaType);
              input?.click();
            }}
            fileInput={
              <input
                ref={(el) => {
                  fileRefs.current[slot] = el;
                }}
                type="file"
                accept="image/*,video/mp4,video/webm,.svga"
                className="hidden"
                onChange={(e) => {
                  const mediaType =
                    (e.target.getAttribute("data-media-type") as HotCardMediaType) || "image";
                  handleUpload(e, slot, mediaType);
                }}
              />
            }
          />
        ))}
      </section>

      <section className="glass-card p-8 space-y-6">
        <h2 className="text-xl font-bold">Right cards</h2>
        <SlotField
          label="Party Star (top)"
          url={(config.party_card_url as string) ?? ""}
          mediaType={(config.party_card_media_type as string) ?? "image"}
          uploading={uploading === "party_card"}
          onUploadClick={(mediaType) => {
            fileRefs.current.party_card?.setAttribute("data-media-type", mediaType);
            fileRefs.current.party_card?.click();
          }}
          fileInput={
            <input
              ref={(el) => {
                fileRefs.current.party_card = el;
              }}
              type="file"
              accept="image/*,video/mp4,video/webm,.svga"
              className="hidden"
              onChange={(e) => {
                const mediaType =
                  (e.target.getAttribute("data-media-type") as HotCardMediaType) || "image";
                handleUpload(e, "party_card", mediaType);
              }}
            />
          }
        />
        <SlotField
          label="Music (bottom)"
          url={(config.music_card_url as string) ?? ""}
          mediaType={(config.music_card_media_type as string) ?? "image"}
          uploading={uploading === "music_card"}
          onUploadClick={(mediaType) => {
            fileRefs.current.music_card?.setAttribute("data-media-type", mediaType);
            fileRefs.current.music_card?.click();
          }}
          fileInput={
            <input
              ref={(el) => {
                fileRefs.current.music_card = el;
              }}
              type="file"
              accept="image/*,video/mp4,video/webm,.svga"
              className="hidden"
              onChange={(e) => {
                const mediaType =
                  (e.target.getAttribute("data-media-type") as HotCardMediaType) || "image";
                handleUpload(e, "music_card", mediaType);
              }}
            />
          }
        />

        <form
          onSubmit={saveRooms}
          className="border border-amber-500/20 bg-amber-500/5 rounded-2xl p-5 space-y-4"
        >
          <div>
            <h3 className="font-bold text-amber-300">Open room on tap</h3>
            <p className="text-xs text-white/45 mt-1">
              Enter the room Short ID (e.g. 1001). Leave empty to clear. App opens this room when
              the user taps the card.
            </p>
          </div>
          <div className="grid md:grid-cols-2 gap-4">
            <label className="block space-y-2">
              <span className="text-sm text-white/70">Party Star → Room Short ID</span>
              <input
                value={partyRoomRef}
                onChange={(e) => setPartyRoomRef(e.target.value)}
                placeholder="e.g. 1001"
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm font-mono focus:outline-none focus:border-amber-500/50"
              />
            </label>
            <label className="block space-y-2">
              <span className="text-sm text-white/70">Music → Room Short ID</span>
              <input
                value={musicRoomRef}
                onChange={(e) => setMusicRoomRef(e.target.value)}
                placeholder="e.g. 1002"
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm font-mono focus:outline-none focus:border-amber-500/50"
              />
            </label>
          </div>
          <button
            type="submit"
            disabled={savingRooms}
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-amber-500 text-black font-bold hover:bg-amber-400 disabled:opacity-50"
          >
            {savingRooms ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
            Save room targets
          </button>
        </form>
      </section>

      <form onSubmit={saveInterval} className="glass-card p-8 flex items-end gap-4">
        <div>
          <label className="text-sm text-white/60 block mb-2">Carousel interval (ms)</label>
          <input
            type="number"
            value={intervalMs}
            onChange={(e) => setIntervalMs(e.target.value)}
            className="bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-white w-40"
            min={2000}
            step={500}
          />
        </div>
        <button
          type="submit"
          className="px-6 py-2 rounded-xl bg-amber-500 text-black font-bold hover:bg-amber-400"
        >
          Save interval
        </button>
      </form>
    </div>
  );
}
function SlotField({
  label,
  url,
  mediaType,
  link,
  uploading,
  onUploadClick,
  fileInput,
}: {
  label: string;
  url: string;
  mediaType: string;
  link?: string;
  uploading: boolean;
  onUploadClick: (mediaType: HotCardMediaType) => void;
  fileInput: React.ReactNode;
}) {
  return (
    <div className="border border-white/10 rounded-2xl p-5 space-y-3">
      <div className="flex justify-between items-start gap-4">
        <div>
          <p className="font-semibold">{label}</p>
          {link && (
            <p className="text-xs text-white/40 mt-1">
              Link: <code className="text-amber-400">{link}</code>
            </p>
          )}
          <p className="text-xs text-white/40">Type: {mediaType}</p>
        </div>
        <div className="flex gap-2">
          {(["image", "svga", "video"] as HotCardMediaType[]).map((t) => (
            <button
              key={t}
              type="button"
              disabled={uploading}
              onClick={() => onUploadClick(t)}
              className="px-3 py-1.5 text-xs rounded-lg bg-white/10 hover:bg-white/20 flex items-center gap-1"
            >
              {uploading ? <Loader2 size={12} className="animate-spin" /> : <Upload size={12} />}
              {t}
            </button>
          ))}
        </div>
      </div>
      {url ? (
        mediaType === "video" ? (
          <video
            src={url}
            className="w-full max-h-40 rounded-xl object-cover"
            muted
            loop
            controls
          />
        ) : (
          <img src={url} alt="" className="w-full max-h-40 rounded-xl object-cover" />
        )
      ) : (
        <p className="text-white/30 text-sm">No media — app uses bundled fallback</p>
      )}
      {fileInput}
    </div>
  );
}
