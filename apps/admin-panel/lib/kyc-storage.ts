export function extractKycObjectPath(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const value = String(raw).trim();
  if (!value) return null;
  if (!/^https?:\/\//i.test(value) && !value.includes("://")) {
    return value.replace(/^\/+/, "");
  }
  try {
    const u = new URL(value);
    const markers = [
      "/storage/v1/object/public/real_name_kyc/",
      "/storage/v1/object/sign/real_name_kyc/",
      "/storage/v1/object/authenticated/real_name_kyc/",
    ];
    for (const marker of markers) {
      const idx = u.pathname.indexOf(marker);
      if (idx >= 0) {
        const rest = u.pathname.slice(idx + marker.length);
        return decodeURIComponent(rest.split("?")[0] || "").replace(/^\/+/, "") || null;
      }
    }
  } catch {
    return null;
  }
  return null;
}
