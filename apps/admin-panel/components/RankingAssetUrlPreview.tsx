"use client";
import { CdnImg } from "@/components/CdnImg";
import { isSvgaAssetUrl } from "@/lib/ranking-asset-media";
import { SvgaPreview } from "@/components/SvgaPreview";
function withCacheBust(url: string, cacheKey?: number) {
  if (url.startsWith("blob:")) return url;
  const base = url.split("?")[0];
  const version = cacheKey ?? Date.now();
  return `${base}?v=${version}`;
}
export function RankingAssetUrlPreview({
  url,
  previewSrc,
  mediaType,
  cacheKey,
  savedUrl,
  className = "max-h-28 rounded-lg object-contain bg-black/30",
}: {
  url?: string;
  previewSrc?: string;
  mediaType?: string;
  cacheKey?: number;
  savedUrl?: string;
  className?: string;
}) {
  const displaySrc = previewSrc ?? url;
  const isSvga =
    mediaType?.toLowerCase() === "svga" || (displaySrc ? isSvgaAssetUrl(displaySrc) : false);
  if (!displaySrc) {
    return <p className="text-white/30 text-xs">Not set</p>;
  }
  return (
    <div className="space-y-2">
      {isSvga ? (
        <>
          <div className="flex items-center gap-2 text-xs text-emerald-300">
            <span className="inline-block w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            SVGA preview
          </div>
          <div className="relative w-full h-40 overflow-hidden rounded-xl bg-black/40">
            <SvgaPreview
              src={withCacheBust(displaySrc, cacheKey)}
              className="absolute inset-0 h-full w-full"
            />
          </div>
        </>
      ) : (
        <CdnImg src={withCacheBust(displaySrc, cacheKey)} alt="Frame preview" className={className} />
      )}
      {savedUrl && !savedUrl.startsWith("blob:") && (
        <p className="text-[10px] text-emerald-400/90 break-all">Saved: {savedUrl}</p>
      )}
    </div>
  );
}
