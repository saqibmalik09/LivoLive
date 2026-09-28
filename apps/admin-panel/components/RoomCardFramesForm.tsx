"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { listRankingAssets, uploadRankingAsset } from "@/app/settings/ranking-assets/actions";
import { RankingAssetUrlPreview } from "@/components/RankingAssetUrlPreview";
import { isSvgaRankingAsset } from "@/lib/ranking-asset-media";
import { Loader2, Upload } from "lucide-react";
type AssetRow = {
  rank_position: number;
  frame_url?: string;
  preview_src?: string;
  frame_media_type?: string;
  previewKey?: number;
};
const RANKS = [
  { rank: 1, label: "Daily TOP 1 room card frame" },
  { rank: 2, label: "Daily TOP 2 room card frame" },
  { rank: 3, label: "Daily TOP 3 room card frame" },
];
export function RoomCardFramesForm() {
  const router = useRouter();
  const [assets, setAssets] = useState<AssetRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState<number | null>(null);
  const fileRefs = useRef<Record<number, HTMLInputElement | null>>({});
  const previewBlobsRef = useRef<Record<number, string>>({});
  async function load() {
    setLoading(true);
    const res = await listRankingAssets("Room", "daily");
    const rows = RANKS.map(({ rank }) => {
      const found = res.assets?.find((a: AssetRow) => a.rank_position === rank);
      const frameUrl = found?.frame_url?.trim() || undefined;
      return {
        ...(found ?? { rank_position: rank }),
        frame_url: frameUrl,
        preview_src: previewBlobsRef.current[rank] ?? frameUrl,
        previewKey: Date.now(),
      };
    });
    setAssets(rows);
    setLoading(false);
  }
  useEffect(() => {
    load();
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
    if (previewBlobsRef.current[rank]?.startsWith("blob:")) {
      URL.revokeObjectURL(previewBlobsRef.current[rank]);
    }
    const localUrl = URL.createObjectURL(file);
    previewBlobsRef.current[rank] = localUrl;
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
    formData.append("category", "Room");
    formData.append("rankingType", "daily");
    formData.append("rankPosition", String(rank));
    formData.append("field", "frame");
    const res = await uploadRankingAsset(formData);
    if (res.success && res.url) {
      setAssets((prev) =>
        prev.map((row) =>
          row.rank_position === rank
            ? {
                ...row,
                frame_url: res.url,
                preview_src: previewBlobsRef.current[rank] ?? res.url,
                frame_media_type: res.mediaType ?? (isSvga ? "svga" : "image"),
                previewKey: Date.now(),
              }
            : row,
        ),
      );
      router.refresh();
    } else {
      if (previewBlobsRef.current[rank]?.startsWith("blob:")) {
        URL.revokeObjectURL(previewBlobsRef.current[rank]);
        delete previewBlobsRef.current[rank];
      }
      await load();
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
    }
    setUploading(null);
    e.target.value = "";
  }
  return (
    <div className="space-y-6">
      <p className="text-white/50 text-sm max-w-2xl">
        These frames appear on Hot tab <strong className="text-white/80">Room Top-3 cards</strong>{" "}
        (left = TOP 1, right column = TOP 2 &amp; 3) and on{" "}
        <strong className="text-white/80">Popular / New</strong> room grid cards for daily ranks
        1–3. Prefer assets sized for each slot (left taller; right cards shorter/wider; grid ~0.72
        aspect).
      </p>

      {loading ? (
        <p className="text-white/50">Loading…</p>
      ) : (
        assets.map((row) => {
          const meta = RANKS.find((r) => r.rank === row.rank_position);
          return (
            <div
              key={row.rank_position}
              className="glass-card p-6 border border-white/10 rounded-2xl space-y-4"
            >
              <div className="flex justify-between items-start gap-4">
                <div>
                  <p className="font-bold">{meta?.label ?? `Rank ${row.rank_position}`}</p>
                  {uploading === row.rank_position && (
                    <p className="text-xs text-amber-300 mt-1">Uploading…</p>
                  )}
                </div>
                <button
                  type="button"
                  disabled={uploading === row.rank_position}
                  onClick={() => fileRefs.current[row.rank_position]?.click()}
                  className="px-4 py-2 rounded-lg bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 text-sm flex items-center gap-2 shrink-0"
                >
                  {uploading === row.rank_position ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Upload size={14} />
                  )}
                  Upload frame
                </button>
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
                <p className="text-white/30 text-sm">No frame uploaded</p>
              )}
              <input
                ref={(el) => {
                  fileRefs.current[row.rank_position] = el;
                }}
                type="file"
                accept="image/png,image/jpeg,image/webp,image/gif,.svga,application/octet-stream"
                className="hidden"
                onChange={(e) => handleUpload(e, row.rank_position)}
              />
            </div>
          );
        })
      )}
    </div>
  );
}
