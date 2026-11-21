"use client";

import { useEffect, useRef, useState } from "react";

type SvgaPreviewProps = {
  src: string;
  className?: string;
};

type SvgaPlayerLike = {
  clear: () => void;
  setVideoItem: (item: unknown) => void;
  setContentMode: (mode: string) => void;
  startAnimation: () => void;
  stopAnimation?: () => void;
  loops: number;
  _onResize?: () => void;
};

/** If CDN fetch fails (CORS / missing object), try Supabase public origin. */
function originFallbackUrl(src: string): string | null {
  try {
    const uri = new URL(src);
    const host = uri.hostname.toLowerCase();
    if (
      host !== "cdn.skliveparty.online" &&
      !host.endsWith(".r2.dev")
    ) {
      return null;
    }
    const path = uri.pathname.replace(/^\//, "");
    if (!path || path.startsWith("cdn-cgi/")) return null;
    // shop_assets are bare keys on CDN; other buckets keep bucket/ prefix.
    const looksBucketPrefixed =
      path.startsWith("app_assets/") ||
      path.startsWith("vip_assets/") ||
      path.startsWith("profiles/") ||
      path.startsWith("chat_assets/") ||
      path.startsWith("posts_assets/") ||
      path.startsWith("family-logos/") ||
      path.startsWith("room_backgrounds/") ||
      path.startsWith("cp_nest_assets/") ||
      path.startsWith("game-icons/") ||
      path.startsWith("support_attachments/");
    const objectPath = looksBucketPrefixed ? path : `shop_assets/${path}`;
    return `https://api.skliveparty.online/storage/v1/object/public/${objectPath}`;
  } catch {
    return null;
  }
}

async function fetchSvgaBlob(url: string): Promise<Blob> {
  const response = await fetch(url, { mode: "cors", credentials: "omit" });
  if (!response.ok) {
    throw new Error(`Could not load SVGA (HTTP ${response.status})`);
  }
  return response.blob();
}

async function resolveSvgaLoadUrl(src: string): Promise<{
  url: string;
  revoke: boolean;
}> {
  if (src.startsWith("blob:")) {
    return { url: src, revoke: false };
  }
  try {
    const blob = await fetchSvgaBlob(src);
    return { url: URL.createObjectURL(blob), revoke: true };
  } catch (primaryErr) {
    const fallback = originFallbackUrl(src);
    if (!fallback || fallback === src) throw primaryErr;
    const blob = await fetchSvgaBlob(fallback);
    return { url: URL.createObjectURL(blob), revoke: true };
  }
}

function waitForBox(el: HTMLElement, tries = 20): Promise<boolean> {
  return new Promise((resolve) => {
    let n = 0;
    const tick = () => {
      const w = el.clientWidth;
      const h = el.clientHeight;
      if (w > 8 && h > 8) {
        resolve(true);
        return;
      }
      n += 1;
      if (n >= tries) {
        resolve(false);
        return;
      }
      requestAnimationFrame(tick);
    };
    tick();
  });
}

/** Center the SVGA canvas in its host (flex — avoids transform fights with the player). */
function fitCanvasInBox(container: HTMLElement) {
  container.style.display = "flex";
  container.style.alignItems = "center";
  container.style.justifyContent = "center";
  container.style.position = "absolute";
  container.style.inset = "0";
  container.style.width = "100%";
  container.style.height = "100%";
  container.style.overflow = "hidden";

  const canvas = container.querySelector("canvas");
  if (!canvas) return;
  const boxW = container.clientWidth;
  const boxH = container.clientHeight;
  if (boxW < 2 || boxH < 2) return;

  const nativeW = canvas.width || canvas.clientWidth || 1;
  const nativeH = canvas.height || canvas.clientHeight || 1;
  const scale = Math.min(boxW / nativeW, boxH / nativeH);
  const drawW = Math.max(1, Math.floor(nativeW * scale));
  const drawH = Math.max(1, Math.floor(nativeH * scale));

  canvas.style.setProperty("position", "relative", "important");
  canvas.style.setProperty("left", "auto", "important");
  canvas.style.setProperty("top", "auto", "important");
  canvas.style.setProperty("right", "auto", "important");
  canvas.style.setProperty("bottom", "auto", "important");
  canvas.style.setProperty("transform", "none", "important");
  canvas.style.setProperty("margin", "0", "important");
  canvas.style.setProperty("display", "block", "important");
  canvas.style.setProperty("width", `${drawW}px`, "important");
  canvas.style.setProperty("height", `${drawH}px`, "important");
  canvas.style.setProperty("max-width", "100%", "important");
  canvas.style.setProperty("max-height", "100%", "important");
}

export function SvgaPreview({ src, className = "" }: SvgaPreviewProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let player: SvgaPlayerLike | null = null;
    let objectUrlToRevoke: string | null = null;
    let cancelled = false;
    let resizeObserver: ResizeObserver | null = null;
    let fitTimers: number[] = [];

    const scheduleFits = (host: HTMLElement) => {
      fitCanvasInBox(host);
      for (const ms of [0, 50, 150, 400]) {
        fitTimers.push(
          window.setTimeout(() => {
            if (!cancelled) fitCanvasInBox(host);
          }, ms),
        );
      }
    };

    async function run() {
      const el = containerRef.current;
      if (!el || !src) return;
      setLoading(true);
      setError(null);
      el.innerHTML = "";
      try {
        await waitForBox(el);
        const { Parser, Player } = await import("svgaplayerweb");
        if (cancelled || !containerRef.current) return;
        const { url: loadUrl, revoke } = await resolveSvgaLoadUrl(src);
        if (revoke) objectUrlToRevoke = loadUrl;
        const parser = new Parser();
        const host = containerRef.current;
        const svgaPlayer = new Player(host) as SvgaPlayerLike;
        await new Promise<void>((resolve, reject) => {
          parser.load(
            loadUrl,
            (videoItem) => {
              if (cancelled) {
                reject(new Error("cancelled"));
                return;
              }
              try {
                svgaPlayer.setVideoItem(videoItem);
                svgaPlayer.setContentMode("AspectFit");
                svgaPlayer.loops = 0;
                svgaPlayer.startAnimation();
                requestAnimationFrame(() => {
                  try {
                    svgaPlayer.setContentMode("AspectFit");
                    svgaPlayer._onResize?.();
                  } catch {
                    /* ignore */
                  }
                  scheduleFits(host);
                });
                player = svgaPlayer;
                resolve();
              } catch (err) {
                reject(err);
              }
            },
            (err) => reject(err ?? new Error("SVGA parser.load failed")),
          );
        });
        if (!cancelled) {
          scheduleFits(host);
          resizeObserver = new ResizeObserver(() => {
            try {
              player?.setContentMode?.("AspectFit");
              player?._onResize?.();
            } catch {
              /* ignore */
            }
            fitCanvasInBox(host);
          });
          resizeObserver.observe(host);
          setLoading(false);
        }
      } catch (e) {
        if (!cancelled) {
          const msg = e instanceof Error ? e.message : "SVGA preview failed";
          setError(msg);
          setLoading(false);
        }
      }
    }
    void run();
    return () => {
      cancelled = true;
      resizeObserver?.disconnect();
      for (const t of fitTimers) window.clearTimeout(t);
      try {
        player?.stopAnimation?.();
        player?.clear?.();
      } catch {
        /* ignore */
      }
      if (objectUrlToRevoke) {
        URL.revokeObjectURL(objectUrlToRevoke);
      }
    };
  }, [src]);

  return (
    <div
      ref={rootRef}
      className={`relative overflow-hidden flex items-center justify-center ${className}`}
    >
      {loading && !error && (
        <div className="absolute inset-0 flex items-center justify-center text-white/50 text-xs z-10 pointer-events-none">
          Loading SVGA…
        </div>
      )}
      {error && (
        <div className="absolute inset-x-2 top-2 z-10 rounded-lg bg-red-500/10 border border-red-500/30 px-3 py-2 text-xs text-red-300">
          SVGA error: {error}
        </div>
      )}
      <div
        ref={containerRef}
        className="absolute inset-0 overflow-hidden bg-transparent flex items-center justify-center"
      />
    </div>
  );
}
