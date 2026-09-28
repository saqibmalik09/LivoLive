"use client";
import { useEffect, useRef, useState } from "react";
import {
  clearRankingAssetFrame,
  listRankingAssets,
  uploadRankingAsset,
  type RankingAssetCategory,
} from "@/app/settings/ranking-assets/actions";
import { RankingAssetUrlPreview } from "@/components/RankingAssetUrlPreview";
import { isSvgaRankingAsset } from "@/lib/ranking-asset-media";
import { Loader2, Trash2, Upload } from "lucide-react";
const DAILY_PERIOD = "daily" as const;
type AssetRow = {
  id?: string;
  rank_position: number;
  frame_url?: string;
  preview_src?: string;
  frame_media_type?: string;
  previewKey?: number;
};
const SLIDE_TABS: {
  category: RankingAssetCategory;
  label: string;
  hint: string;
}[] = [
  {
    category: "Podium",
    label: "Default (all)",
    hint: "Used on every slide when that slide has no own frame for a seat.",
  },
  {
    category: "PodiumRoom",
    label: "Room",
    hint: "Optional — overrides Default only on the Room podium slide.",
  },
  {
    category: "PodiumAgency",
    label: "Agency",
    hint: "Optional — overrides Default only on the Agency podium slide.",
  },
  {
    category: "PodiumCharm",
    label: "Charm",
    hint: "Optional — overrides Default only on the Charm podium slide.",
  },
  {
    category: "PodiumWealth",
    label: "Wealth",
    hint: "Optional — overrides Default only on the Wealth podium slide.",
  },
];
const RANK_SLOTS: {
  rank: number;
  title: string;
  hint: string;
}[] = [
  { rank: 2, title: "TOP 2 frame", hint: "Left podium seat" },
  { rank: 1, title: "TOP 1 frame", hint: "Center podium seat" },
  { rank: 3, title: "TOP 3 frame", hint: "Right podium seat" },
];
export function RankingAssetsForm() {
  const [activeCategory, setActiveCategory] = useState<RankingAssetCategory>("Podium");
  const [assets, setAssets] = useState<AssetRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState<number | null>(null);
  const [clearing, setClearing] = useState<number | null>(null);
  const fileRefs = useRef<Record<number, HTMLInputElement | null>>({});
  const previewBlobsRef = useRef<Record<string, string>>({});
  const blobKey = (rank: number) => `${activeCategory}-${rank}`;
  function rowFor(rank: number): AssetRow {
    return (
      assets.find((a) => a.rank_position === rank) ?? {
        rank_position: rank,
      }
    );
  }
  async function loadAssets(category: RankingAssetCategory) {
    setLoading(true);
    const res = await listRankingAssets(category, DAILY_PERIOD);
    const rows: AssetRow[] = [1, 2, 3].map((rank) => {
      const found = res.assets?.find((a: AssetRow) => a.rank_position === rank);
      const frameUrl = found?.frame_url?.trim() || undefined;
      const previewSrc = previewBlobsRef.current[`${category}-${rank}`] ?? frameUrl;
      return {
        ...(found ?? { rank_position: rank }),
        frame_url: frameUrl,
        preview_src: previewSrc,
        previewKey: Date.now(),
      };
    });
    setAssets(rows);
    setLoading(false);
  }
  useEffect(() => {
    void loadAssets(activeCategory);
  }, [activeCategory]);
  useEffect(() => {
    return () => {
      Object.values(previewBlobsRef.current).forEach((url) => {
        if (url.startsWith("blob:")) URL.revokeObjectURL(url);
      });
    };
  }, []);
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>, rank: number) {
    const file = e.target.files?.[0];
    if (!file) return;
    const isSvga = isSvgaRankingAsset(file.name, file.type);
    const key = blobKey(rank);
    if (previewBlobsRef.current[key]?.startsWith("blob:")) {
      URL.revokeObjectURL(previewBlobsRef.current[key]);
    }
    const localUrl = URL.createObjectURL(file);
    previewBlobsRef.current[key] = localUrl;
    setAssets((prev) =>
      prev.map((row) =>
        row.rank_position === rank
          ? {
              ...row,
              preview_src: localUrl,
              frame_media_type: isSvga ? "svga" : "image",
              previewKey: Date.now(),
            }
          : row,
      ),
    );
    setUploading(rank);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("category", activeCategory);
    formData.append("rankingType", DAILY_PERIOD);
    formData.append("rankPosition", String(rank));
    formData.append("field", "frame");
    const res = await uploadRankingAsset(formData);
    if (res.success && res.url) {
      const keptBlob = previewBlobsRef.current[key];
      setAssets((prev) =>
        prev.map((row) =>
          row.rank_position === rank
            ? {
                ...row,
                frame_url: res.url,
                preview_src: keptBlob ?? res.url,
                frame_media_type: res.mediaType ?? (isSvga ? "svga" : "image"),
                previewKey: Date.now(),
              }
            : row,
        ),
      );
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
    }
    setUploading(null);
    e.target.value = "";
  }
  async function handleClear(rank: number) {
    if (!confirm(`Clear TOP ${rank} frame for this tab?`)) return;
    setClearing(rank);
    const res = await clearRankingAssetFrame({
      category: activeCategory,
      rankingType: DAILY_PERIOD,
      rankPosition: rank,
    });
    setClearing(null);
    if (!res.success) {
      alert(res.error ?? "Clear failed");
      return;
    }
    const key = blobKey(rank);
    if (previewBlobsRef.current[key]?.startsWith("blob:")) {
      URL.revokeObjectURL(previewBlobsRef.current[key]);
    }
    delete previewBlobsRef.current[key];
    setAssets((prev) =>
      prev.map((row) =>
        row.rank_position === rank
          ? {
              ...row,
              frame_url: undefined,
              preview_src: undefined,
              frame_media_type: "image",
              previewKey: Date.now(),
            }
          : row,
      ),
    );
  }
  const activeTab = SLIDE_TABS.find((t) => t.category === activeCategory);
  return (
    <div className="space-y-6">
      <p className="text-white/50 text-sm max-w-3xl">
        Set <span className="text-white/80 font-semibold">TOP 1 / 2 / 3</span> frames separately.
        Optionally override per slide (Room, Agency, Charm, Wealth). Empty seats on a slide fall
        back to <span className="text-white/80 font-semibold">Default (all)</span>.
      </p>

      <div className="flex flex-wrap gap-2">
        {SLIDE_TABS.map((tab) => {
          const selected = tab.category === activeCategory;
          return (
            <button
              key={tab.category}
              type="button"
              onClick={() => setActiveCategory(tab.category)}
              className={`px-4 py-2 rounded-xl text-sm font-semibold transition-colors ${
                selected ? "bg-amber-500 text-black" : "bg-white/5 text-white/70 hover:bg-white/10"
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {activeTab && <p className="text-white/40 text-sm">{activeTab.hint}</p>}

      {loading ? (
        <p className="text-white/50">Loading…</p>
      ) : (
        <div className="grid gap-6 md:grid-cols-3">
          {RANK_SLOTS.map(({ rank, title, hint }) => {
            const row = rowFor(rank);
            const busy = uploading === rank || clearing === rank;
            return (
              <div
                key={`${activeCategory}-${rank}`}
                className="glass-card p-6 border border-white/10 rounded-2xl space-y-4"
              >
                <div className="space-y-1">
                  <p className="font-bold">{title}</p>
                  <p className="text-xs text-white/40">{hint}</p>
                  {uploading === rank && <p className="text-xs text-amber-300">Uploading…</p>}
                </div>

                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => fileRefs.current[rank]?.click()}
                    className="px-4 py-2 rounded-lg bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 text-sm flex items-center gap-2 shrink-0 disabled:opacity-50"
                  >
                    {uploading === rank ? (
                      <Loader2 size={14} className="animate-spin" />
                    ) : (
                      <Upload size={14} />
                    )}
                    Upload
                  </button>
                  {(row.preview_src || row.frame_url) && (
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void handleClear(rank)}
                      className="px-3 py-2 rounded-lg bg-red-500/15 text-red-300 hover:bg-red-500/25 text-sm flex items-center gap-2 disabled:opacity-50"
                    >
                      {clearing === rank ? (
                        <Loader2 size={14} className="animate-spin" />
                      ) : (
                        <Trash2 size={14} />
                      )}
                      Clear
                    </button>
                  )}
                </div>

                {row.preview_src || row.frame_url ? (
                  <RankingAssetUrlPreview
                    url={row.frame_url}
                    previewSrc={row.preview_src ?? row.frame_url}
                    savedUrl={row.frame_url}
                    mediaType={row.frame_media_type}
                    cacheKey={row.previewKey}
                    className="max-h-36 rounded-xl object-contain bg-black/30"
                  />
                ) : (
                  <p className="text-white/30 text-sm">
                    {activeCategory === "Podium"
                      ? "No frame — seat shows avatar only"
                      : "Empty — falls back to Default (all)"}
                  </p>
                )}

                <input
                  ref={(el) => {
                    fileRefs.current[rank] = el;
                  }}
                  type="file"
                  accept="image/png,image/jpeg,image/webp,image/gif,.svga,application/octet-stream"
                  className="hidden"
                  onChange={(e) => handleUpload(e, rank)}
                />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
