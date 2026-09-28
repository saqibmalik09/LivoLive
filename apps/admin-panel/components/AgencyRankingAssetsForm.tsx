"use client";
import { useEffect, useRef, useState } from "react";
import { listRankingAssets, uploadRankingAsset } from "@/app/settings/ranking-assets/actions";
import { RankingAssetUrlPreview } from "@/components/RankingAssetUrlPreview";
import { isSvgaRankingAsset } from "@/lib/ranking-asset-media";
import { Loader2, Upload } from "lucide-react";
const AGENCY_CATEGORY = "Agency" as const;
const PERIODS = ["daily", "weekly", "monthly"] as const;
type Period = (typeof PERIODS)[number];
type AssetField = "frame" | "badge";
type AssetRow = {
  id?: string;
  rank_position: number;
  frame_url?: string;
  badge_url?: string;
  frame_preview?: string;
  badge_preview?: string;
  frame_media_type?: string;
  framePreviewKey?: number;
  badgePreviewKey?: number;
};
export function AgencyRankingAssetsForm() {
  const [period, setPeriod] = useState<Period>("daily");
  const [assets, setAssets] = useState<AssetRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState<string | null>(null);
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  const previewBlobsRef = useRef<Record<string, string>>({});
  async function loadAssets(selectedPeriod: Period) {
    setLoading(true);
    const res = await listRankingAssets(AGENCY_CATEGORY, selectedPeriod);
    const rows: AssetRow[] = [1, 2, 3].map((rank) => {
      const found = res.assets?.find((a: AssetRow) => a.rank_position === rank);
      const frameUrl = found?.frame_url?.trim() || undefined;
      const badgeUrl = found?.badge_url?.trim() || undefined;
      const frameBlob = previewBlobsRef.current[`${selectedPeriod}-${rank}-frame`];
      const badgeBlob = previewBlobsRef.current[`${selectedPeriod}-${rank}-badge`];
      return {
        ...(found ?? { rank_position: rank }),
        frame_url: frameUrl,
        badge_url: badgeUrl,
        frame_preview: frameBlob ?? frameUrl,
        badge_preview: badgeBlob ?? badgeUrl,
        framePreviewKey: Date.now(),
        badgePreviewKey: Date.now(),
      };
    });
    setAssets(rows);
    setLoading(false);
  }
  useEffect(() => {
    void loadAssets(period);
  }, [period]);
  useEffect(() => {
    return () => {
      Object.values(previewBlobsRef.current).forEach((url) => {
        if (url.startsWith("blob:")) URL.revokeObjectURL(url);
      });
    };
  }, []);
  async function handleUpload(
    e: React.ChangeEvent<HTMLInputElement>,
    rank: number,
    field: AssetField,
  ) {
    const file = e.target.files?.[0];
    if (!file) return;
    const blobKey = `${period}-${rank}-${field}`;
    const isSvga = field === "frame" && isSvgaRankingAsset(file.name, file.type);
    if (previewBlobsRef.current[blobKey]?.startsWith("blob:")) {
      URL.revokeObjectURL(previewBlobsRef.current[blobKey]);
    }
    const localUrl = URL.createObjectURL(file);
    previewBlobsRef.current[blobKey] = localUrl;
    setAssets((prev) =>
      prev.map((row) =>
        row.rank_position === rank
          ? {
              ...row,
              ...(field === "frame"
                ? {
                    frame_preview: localUrl,
                    frame_media_type: isSvga ? "svga" : "image",
                    framePreviewKey: Date.now(),
                  }
                : {
                    badge_preview: localUrl,
                    badgePreviewKey: Date.now(),
                  }),
            }
          : row,
      ),
    );
    setUploading(blobKey);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("category", AGENCY_CATEGORY);
    formData.append("rankingType", period);
    formData.append("rankPosition", String(rank));
    formData.append("field", field);
    const res = await uploadRankingAsset(formData);
    if (res.success && res.url) {
      setAssets((prev) =>
        prev.map((row) =>
          row.rank_position === rank
            ? {
                ...row,
                ...(field === "frame"
                  ? {
                      frame_url: res.url,
                      frame_preview: previewBlobsRef.current[blobKey] ?? res.url,
                      frame_media_type: res.mediaType ?? (isSvga ? "svga" : "image"),
                      framePreviewKey: Date.now(),
                    }
                  : {
                      badge_url: res.url,
                      badge_preview: previewBlobsRef.current[blobKey] ?? res.url,
                      badgePreviewKey: Date.now(),
                    }),
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
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-2">
        {PERIODS.map((p) => (
          <button
            key={p}
            type="button"
            onClick={() => setPeriod(p)}
            className={`rounded-xl px-4 py-2 text-xs font-bold uppercase tracking-widest transition-colors ${
              period === p
                ? "bg-amber-500/30 text-amber-200"
                : "bg-white/5 text-white/40 hover:bg-white/10"
            }`}
          >
            {p}
          </button>
        ))}
      </div>

      <p className="text-white/50 text-sm max-w-2xl">
        Gift Center Agency tab — TOP 1 / 2 / 3 frame and badge for each ranking period. Upload PNG,
        JPG, WebP, GIF, or SVGA for frames.
      </p>

      {loading ? (
        <p className="text-white/50">Loading…</p>
      ) : (
        <div className="grid gap-6">
          {assets.map((row) => (
            <div
              key={row.rank_position}
              className="glass-card p-6 border border-white/10 rounded-2xl space-y-5"
            >
              <p className="font-bold capitalize">
                {period} TOP {row.rank_position}
              </p>

              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-3">
                  <div className="flex justify-between items-center gap-4">
                    <p className="text-sm text-white/70">Frame</p>
                    <button
                      type="button"
                      disabled={uploading === `${period}-${row.rank_position}-frame`}
                      onClick={() => fileRefs.current[`${row.rank_position}-frame`]?.click()}
                      className="px-3 py-1.5 rounded-lg bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 text-xs flex items-center gap-2"
                    >
                      {uploading === `${period}-${row.rank_position}-frame` ? (
                        <Loader2 size={12} className="animate-spin" />
                      ) : (
                        <Upload size={12} />
                      )}
                      Upload
                    </button>
                  </div>
                  {row.frame_preview || row.frame_url ? (
                    <RankingAssetUrlPreview
                      url={row.frame_url}
                      previewSrc={row.frame_preview ?? row.frame_url}
                      savedUrl={row.frame_url}
                      mediaType={row.frame_media_type}
                      cacheKey={row.framePreviewKey}
                      className="max-h-36 rounded-xl object-contain bg-black/30"
                    />
                  ) : (
                    <p className="text-white/30 text-sm">No frame uploaded</p>
                  )}
                  <input
                    ref={(el) => {
                      fileRefs.current[`${row.rank_position}-frame`] = el;
                    }}
                    type="file"
                    accept="image/png,image/jpeg,image/webp,image/gif,.svga,application/octet-stream"
                    className="hidden"
                    onChange={(e) => handleUpload(e, row.rank_position, "frame")}
                  />
                </div>

                <div className="space-y-3">
                  <div className="flex justify-between items-center gap-4">
                    <p className="text-sm text-white/70">Badge</p>
                    <button
                      type="button"
                      disabled={uploading === `${period}-${row.rank_position}-badge`}
                      onClick={() => fileRefs.current[`${row.rank_position}-badge`]?.click()}
                      className="px-3 py-1.5 rounded-lg bg-sky-500/20 text-sky-300 hover:bg-sky-500/30 text-xs flex items-center gap-2"
                    >
                      {uploading === `${period}-${row.rank_position}-badge` ? (
                        <Loader2 size={12} className="animate-spin" />
                      ) : (
                        <Upload size={12} />
                      )}
                      Upload
                    </button>
                  </div>
                  {row.badge_preview || row.badge_url ? (
                    <RankingAssetUrlPreview
                      url={row.badge_url}
                      previewSrc={row.badge_preview ?? row.badge_url}
                      savedUrl={row.badge_url}
                      mediaType="image"
                      cacheKey={row.badgePreviewKey}
                      className="max-h-24 rounded-xl object-contain bg-black/30"
                    />
                  ) : (
                    <p className="text-white/30 text-sm">No badge uploaded</p>
                  )}
                  <input
                    ref={(el) => {
                      fileRefs.current[`${row.rank_position}-badge`] = el;
                    }}
                    type="file"
                    accept="image/png,image/jpeg,image/webp,image/gif"
                    className="hidden"
                    onChange={(e) => handleUpload(e, row.rank_position, "badge")}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
