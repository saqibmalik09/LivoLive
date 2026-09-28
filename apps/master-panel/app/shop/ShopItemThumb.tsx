'use client';

import { useEffect, useRef, useState } from 'react';
import { Loader2, ShoppingBag } from 'lucide-react';
import { SvgaPreview } from '@/components/SvgaPreview';
import { publicMediaUrl, storageThumbUrl } from '@/lib/media-url';

/**
 * Shop card preview:
 * - Has image → show static image (no SVGA swap / blink)
 * - No image + has SVGA → centered SVGA preview
 */
export function ShopItemThumb({
  imageUrl,
  svgaUrl,
  name,
}: {
  imageUrl: string | null | undefined;
  svgaUrl?: string | null | undefined;
  name: string;
}) {
  const rootRef = useRef<HTMLDivElement>(null);
  const thumb = storageThumbUrl(imageUrl, 320);
  const full = publicMediaUrl(imageUrl);
  const svga = publicMediaUrl(svgaUrl);

  const [src, setSrc] = useState(thumb || full);
  const [failed, setFailed] = useState(!src);
  const [imgLoading, setImgLoading] = useState(Boolean(thumb || full));
  const [svgaReady, setSvgaReady] = useState(false);

  const hasImageUrl = Boolean((imageUrl || '').trim());
  const hasImage = hasImageUrl && Boolean(src) && !failed;
  const hasSvga = Boolean(svga);
  // Only play SVGA when there is no usable static image.
  const useSvga = hasSvga && (!hasImageUrl || failed);

  useEffect(() => {
    const next = thumb || full;
    setSrc(next);
    setFailed(!next);
    setImgLoading(Boolean(next));
  }, [thumb, full]);

  useEffect(() => {
    const el = rootRef.current;
    if (!el || !useSvga || svgaReady) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && entry.intersectionRatio > 0.1) {
          setSvgaReady(true);
        }
      },
      { threshold: [0, 0.1, 0.25], rootMargin: '100px 0px' },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [useSvga, svgaReady]);

  return (
    <div
      ref={rootRef}
      className="relative w-full h-full flex items-center justify-center"
    >
      {useSvga && svgaReady ? (
        <div className="absolute inset-2 overflow-hidden rounded-xl flex items-center justify-center">
          <SvgaPreview
            src={svga}
            className="absolute inset-0 h-full w-full"
          />
        </div>
      ) : useSvga && !svgaReady ? (
        <div className="flex flex-col items-center gap-2 text-amber-300/80 px-4 text-center">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span className="text-[9px] font-black uppercase tracking-widest text-white/40">
            Loading…
          </span>
        </div>
      ) : hasImage ? (
        <>
          {imgLoading && (
            <div className="absolute inset-0 z-10 flex items-center justify-center pointer-events-none">
              <Loader2 className="h-6 w-6 animate-spin text-amber-400/80" />
            </div>
          )}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            key={src}
            src={src}
            alt={name}
            loading="lazy"
            decoding="async"
            referrerPolicy="no-referrer"
            onLoad={() => setImgLoading(false)}
            onError={() => {
              if (full && src !== full) {
                setSrc(full);
                setImgLoading(true);
                return;
              }
              setFailed(true);
              setImgLoading(false);
            }}
            className={`w-4/5 h-4/5 object-contain ${
              imgLoading ? 'opacity-0' : 'opacity-100'
            }`}
          />
        </>
      ) : (
        <ShoppingBag className="text-white/20" size={36} />
      )}

      {hasSvga && (
        <div className="absolute bottom-2 left-2 bg-blue-500/20 border border-blue-500/30 text-blue-300 px-2 py-0.5 rounded text-[8px] font-black uppercase tracking-widest z-10">
          SVGA
        </div>
      )}
    </div>
  );
}
