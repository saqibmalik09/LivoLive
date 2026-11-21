"use client";

import type { ImgHTMLAttributes } from "react";
import { publicMediaUrl } from "@/lib/media-url";

/**
 * Drop-in `<img>` that rewrites Supabase/origin public URLs to CDN.
 * KYC / private URLs are left unchanged by publicMediaUrl.
 */
export function CdnImg({
  src,
  alt = "",
  ...rest
}: ImgHTMLAttributes<HTMLImageElement>) {
  const resolved =
    typeof src === "string" && src.trim() ? publicMediaUrl(src) : src;
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={resolved || undefined} alt={alt} {...rest} />;
}
