"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  uploadRankingPodiumBg,
  updateRankingPodiumConfig,
  type PodiumBgSlot,
} from "@/app/settings/ranking-podium/actions";
import { Loader2, Upload } from "lucide-react";
type Config = Record<string, string | number | null | undefined>;
const SLOTS: {
  slot: PodiumBgSlot;
  label: string;
}[] = [
  { slot: "room", label: "Room podium background" },
  { slot: "agency", label: "Agency podium background" },
  { slot: "charm", label: "Charm podium background" },
  { slot: "wealth", label: "Wealth podium background" },
];
export function RankingPodiumForm({ config }: { config: Config }) {
  const router = useRouter();
  const [uploading, setUploading] = useState<PodiumBgSlot | null>(null);
  const [intervalMs, setIntervalMs] = useState(String(config.slide_interval_ms ?? 5000));
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>, slot: PodiumBgSlot) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(slot);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("slot", slot);
    const res = await uploadRankingPodiumBg(formData);
    if (res.success) router.refresh();
    else alert(`Upload failed: ${res.error}`);
    setUploading(null);
    e.target.value = "";
  }
  async function saveInterval(e: React.FormEvent) {
    e.preventDefault();
    const ms = parseInt(intervalMs, 10);
    const res = await updateRankingPodiumConfig({
      slide_interval_ms: Number.isFinite(ms) ? ms : 5000,
    });
    if (!res.success) alert(res.error);
    else router.refresh();
  }
  return (
    <div className="space-y-8">
      {SLOTS.map(({ slot, label }) => {
        const url = (config[`${slot}_bg_url`] as string) ?? "";
        return (
          <div key={slot} className="glass-card p-6 border border-white/10 rounded-2xl space-y-3">
            <div className="flex justify-between items-center">
              <p className="font-semibold">{label}</p>
              <button
                type="button"
                disabled={uploading === slot}
                onClick={() => fileRefs.current[slot]?.click()}
                className="px-4 py-2 rounded-lg bg-white/10 hover:bg-white/20 text-sm flex items-center gap-2"
              >
                {uploading === slot ? (
                  <Loader2 size={14} className="animate-spin" />
                ) : (
                  <Upload size={14} />
                )}
                Upload PNG
              </button>
            </div>
            {url ? (
              <CdnImg src={url} alt="" className="w-full max-h-36 rounded-xl object-cover" />
            ) : (
              <p className="text-white/30 text-sm">No image — app uses bundled fallback</p>
            )}
            <input
              ref={(el) => {
                fileRefs.current[slot] = el;
              }}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => handleUpload(e, slot)}
            />
          </div>
        );
      })}

      <form onSubmit={saveInterval} className="glass-card p-6 flex items-end gap-4">
        <div>
          <label className="text-sm text-white/60 block mb-2">Slide interval (ms)</label>
          <input
            type="number"
            value={intervalMs}
            onChange={(e) => setIntervalMs(e.target.value)}
            className="bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-white w-40"
            min={3000}
            step={500}
          />
        </div>
        <button
          type="submit"
          className="px-6 py-2 rounded-xl bg-violet-500 text-white font-bold hover:bg-violet-400"
        >
          Save interval
        </button>
      </form>
    </div>
  );
}
