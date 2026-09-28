export function isSvgaAssetUrl(url?: string | null): boolean {
  if (!url) return false;
  try {
    return new URL(url.trim()).pathname.toLowerCase().endsWith(".svga");
  } catch {
    return url.trim().toLowerCase().includes(".svga");
  }
}
export function isSvgaRankingAsset(fileName: string, fileType = ""): boolean {
  const lowerName = fileName.toLowerCase();
  const lowerType = fileType.toLowerCase();
  return (
    lowerName.endsWith(".svga") ||
    lowerType.includes("svga") ||
    (lowerType === "application/octet-stream" && lowerName.endsWith(".svga"))
  );
}
export function resolveRankingAssetContentType(file: Blob, fileName: string): string {
  if (isSvgaRankingAsset(fileName, file.type)) {
    return "application/octet-stream";
  }
  if (file.type) return file.type;
  const ext = fileName.split(".").pop()?.toLowerCase();
  switch (ext) {
    case "png":
      return "image/png";
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "webp":
      return "image/webp";
    case "gif":
      return "image/gif";
    case "svga":
      return "application/octet-stream";
    default:
      return "application/octet-stream";
  }
}
export function resolveRankingAssetExtension(fileName: string, fileType = ""): string {
  if (isSvgaRankingAsset(fileName, fileType)) {
    return "svga";
  }
  const ext = fileName.split(".").pop()?.toLowerCase();
  const allowed = new Set(["png", "jpg", "jpeg", "webp", "gif", "svga"]);
  if (ext && allowed.has(ext)) return ext;
  return "png";
}
