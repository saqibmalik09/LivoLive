export const TOP_BANNER_WIDTH = 1280;
export const TOP_BANNER_HEIGHT = 560;
export const PROMO_BANNER_WIDTH = 1080;
export const PROMO_BANNER_HEIGHT = 320;
export type PromoBannerSizeSpec = {
  width: number;
  height: number;
  label: string;
  aspectClass: string;
};
export function promoBannerSpecForPlacement(
  placement: "top" | "after_rooms" | "profile" | string,
): PromoBannerSizeSpec {
  if (placement === "top") {
    return {
      width: TOP_BANNER_WIDTH,
      height: TOP_BANNER_HEIGHT,
      label: `${TOP_BANNER_WIDTH}×${TOP_BANNER_HEIGHT}px`,
      aspectClass: `aspect-[${TOP_BANNER_WIDTH}/${TOP_BANNER_HEIGHT}]`,
    };
  }
  return {
    width: PROMO_BANNER_WIDTH,
    height: PROMO_BANNER_HEIGHT,
    label: `${PROMO_BANNER_WIDTH}×${PROMO_BANNER_HEIGHT}px`,
    aspectClass: `aspect-[${PROMO_BANNER_WIDTH}/${PROMO_BANNER_HEIGHT}]`,
  };
}
export const PROMO_BANNER_SIZE_LABEL = `${PROMO_BANNER_WIDTH}×${PROMO_BANNER_HEIGHT}px`;
export const PROMO_BANNER_ASPECT_CLASS = "aspect-[1080/320]";
export function promoBannerSizeHint(where: string, placement: string = "after_rooms"): string {
  const spec = promoBannerSpecForPlacement(placement);
  return `${where} Upload exactly ${spec.label} (ratio ${spec.width}:${spec.height}) so the image fits the app without cropping.`;
}
export function promoBannerSizeIssue(
  width: number,
  height: number,
  placement: string = "after_rooms",
): string | null {
  const spec = promoBannerSpecForPlacement(placement);
  if (width === spec.width && height === spec.height) {
    return null;
  }
  const scaleW = width / spec.width;
  const scaleH = height / spec.height;
  if (Number.isInteger(scaleW) && scaleW >= 1 && scaleW === scaleH) {
    return null;
  }
  return `Exact size required: ${spec.label}. Your file is ${width}×${height}px.`;
}
