export function toDirectDownloadUrl(raw: string): string {
  const url = raw.trim();
  if (!url) return url;
  if (
    url.includes("drive.google.com/uc?") ||
    url.includes("drive.usercontent.google.com/download")
  ) {
    return url;
  }
  const fileMatch = url.match(/drive\.google\.com\/file\/d\/([^/?#]+)/i);
  if (fileMatch?.[1]) {
    return `https://drive.usercontent.google.com/download?id=${fileMatch[1]}&export=download&confirm=t`;
  }
  if (/drive\.google\.com/i.test(url)) {
    const idMatch = url.match(/[?&]id=([^&#]+)/i);
    if (idMatch?.[1]) {
      return `https://drive.usercontent.google.com/download?id=${idMatch[1]}&export=download&confirm=t`;
    }
  }
  return url;
}
