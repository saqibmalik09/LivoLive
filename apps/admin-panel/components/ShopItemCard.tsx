"use client";
import { CdnImg } from "@/components/CdnImg";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Gift, Loader2, Pencil, ShoppingBag } from "lucide-react";
import { SvgaPreview } from "@/components/SvgaPreview";
import { ShopSendItemModal } from "@/components/ShopSendItemModal";
import { publicMediaUrl, storageThumbUrl } from "@/lib/media-url";

type ShopItemCardProps = {
  id: string;
  name: string;
  imageUrl?: string | null;
  svgaUrl?: string | null;
  categoryName?: string | null;
  priceCoins: number;
  durationDays: number;
  isActive: boolean;
};

/**
 * Preview rule (same as master panel):
 * - Has image → show static image only (no SVGA blink/swap)
 * - No image + SVGA → centered SVGA when in view
 */
export function ShopItemCard({
  id,
  name,
  imageUrl,
  svgaUrl,
  categoryName,
  priceCoins,
  durationDays,
  isActive,
}: ShopItemCardProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const [sendOpen, setSendOpen] = useState(false);
  const [imgFailed, setImgFailed] = useState(false);
  const [imgSrc, setImgSrc] = useState(() => storageThumbUrl(imageUrl, 320) || publicMediaUrl(imageUrl));
  const [imgLoading, setImgLoading] = useState(Boolean(imageUrl?.trim()));
  const [svgaReady, setSvgaReady] = useState(false);

  const resolvedFullImage = publicMediaUrl(imageUrl);
  const resolvedSvga = publicMediaUrl(svgaUrl);
  const hasImageUrl = Boolean((imageUrl || "").trim());
  const hasImage = hasImageUrl && Boolean(imgSrc) && !imgFailed;
  const hasSvga = Boolean(resolvedSvga);
  const useSvga = hasSvga && (!hasImageUrl || imgFailed);

  useEffect(() => {
    const next = storageThumbUrl(imageUrl, 320) || publicMediaUrl(imageUrl);
    setImgSrc(next);
    setImgFailed(!next);
    setImgLoading(Boolean(next));
    setSvgaReady(false);
  }, [imageUrl]);

  useEffect(() => {
    const el = rootRef.current;
    if (!el || !useSvga || svgaReady) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && entry.intersectionRatio > 0.1) {
          setSvgaReady(true);
        }
      },
      { threshold: [0, 0.1, 0.25], rootMargin: "100px 0px" },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [useSvga, svgaReady]);

  return (
    <>
      <div
        ref={rootRef}
        role="button"
        tabIndex={0}
        onClick={() => setSendOpen(true)}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            setSendOpen(true);
          }
        }}
        className="glass-card group hover:border-amber-500/30 transition-all p-4 overflow-hidden relative block cursor-pointer text-left w-full"
      >
        <div className="aspect-square rounded-2xl bg-black/40 border border-white/5 overflow-hidden flex items-center justify-center relative mb-6">
          {useSvga && svgaReady ? (
            <div className="absolute inset-2 overflow-hidden rounded-xl flex items-center justify-center">
              <SvgaPreview
                src={resolvedSvga}
                className="absolute inset-0 h-full w-full"
              />
            </div>
          ) : useSvga && !svgaReady ? (
            <div className="flex flex-col items-center gap-2 text-amber-300/80 px-4 text-center">
              <Loader2 size={24} className="animate-spin opacity-80" />
              <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                Loading…
              </span>
            </div>
          ) : hasImage ? (
            <>
              {imgLoading && (
                <div className="absolute inset-0 z-10 flex items-center justify-center pointer-events-none">
                  <Loader2 size={24} className="animate-spin text-amber-400/80" />
                </div>
              )}
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <CdnImg
                key={imgSrc}
                src={imgSrc}
                alt={name}
                loading="lazy"
                decoding="async"
                referrerPolicy="no-referrer"
                onLoad={() => setImgLoading(false)}
                onError={() => {
                  if (resolvedFullImage && imgSrc !== resolvedFullImage) {
                    setImgSrc(resolvedFullImage);
                    setImgLoading(true);
                    return;
                  }
                  setImgFailed(true);
                  setImgLoading(false);
                }}
                className={`w-4/5 h-4/5 object-contain group-hover:scale-110 transition-transform duration-500 ${
                  imgLoading ? "opacity-0" : "opacity-100"
                }`}
              />
            </>
          ) : (
            <ShoppingBag className="text-white/10" size={48} />
          )}

          <div className="absolute top-3 right-3 bg-black/60 backdrop-blur-md border border-white/10 px-3 py-1.5 rounded-full flex items-center gap-2 z-10">
            <div
              className={`w-1.5 h-1.5 rounded-full ${isActive ? "bg-emerald-500" : "bg-red-500"}`}
            />
            <span className="text-[10px] font-black uppercase tracking-widest text-white/80">
              {isActive ? "Live" : "Hidden"}
            </span>
          </div>

          {hasSvga && (
            <div className="absolute bottom-3 left-3 bg-blue-500/20 border border-blue-500/30 text-blue-400 px-2 py-1 rounded text-[8px] font-black uppercase tracking-widest z-10">
              SVGA
            </div>
          )}

          <Link
            href={`/shop/${id}`}
            onClick={(e) => e.stopPropagation()}
            className="absolute bottom-3 right-3 z-10 p-2 rounded-xl bg-black/60 border border-white/10 text-white/60 hover:text-amber-300 hover:border-amber-500/40 transition-colors"
            title="Edit item"
          >
            <Pencil size={14} />
          </Link>
        </div>

        <div className="space-y-3">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-amber-500/60 mb-0.5">
              {categoryName}
            </p>
            <h3 className="font-black text-xl tracking-tight text-white/90 leading-none">{name}</h3>
          </div>

          <div className="flex items-center justify-between pt-2">
            <div className="flex items-baseline gap-1">
              <span className="text-2xl font-black text-white">{priceCoins.toLocaleString()}</span>
              <span className="text-[10px] font-bold text-white/30 uppercase tracking-widest">
                Coins
              </span>
            </div>
            <div className="text-[10px] font-bold text-white/20 uppercase tracking-widest">
              {durationDays} Days
            </div>
          </div>

          <div className="flex items-center gap-2 text-amber-400/80 text-[10px] font-black uppercase tracking-widest pt-1">
            <Gift size={12} />
            Click to send to user
          </div>
        </div>

        <div className="absolute inset-0 bg-amber-500 opacity-0 group-hover:opacity-10 transition-opacity pointer-events-none" />
      </div>

      <ShopSendItemModal
        itemId={id}
        itemName={name}
        defaultDays={durationDays}
        open={sendOpen}
        onClose={() => setSendOpen(false)}
      />
    </>
  );
}
