export function normalizeCountryCode(code?: string | null): string | null {
  if (!code?.trim()) return null;
  const upper = code.trim().toUpperCase().slice(0, 2);
  if (!/^[A-Z]{2}$/.test(upper)) return null;
  return upper;
}
export function countryFlagImageUrl(code?: string | null, width = 40): string | null {
  const iso = normalizeCountryCode(code);
  if (!iso) return null;
  return `https://flagcdn.com/w${width}/${iso.toLowerCase()}.png`;
}
export const ADMIN_COUNTRY_OPTIONS: {
  code: string;
  name: string;
}[] = [
  { code: "PK", name: "Pakistan" },
  { code: "IN", name: "India" },
  { code: "BD", name: "Bangladesh" },
  { code: "AF", name: "Afghanistan" },
  { code: "AE", name: "United Arab Emirates" },
  { code: "SA", name: "Saudi Arabia" },
  { code: "QA", name: "Qatar" },
  { code: "KW", name: "Kuwait" },
  { code: "BH", name: "Bahrain" },
  { code: "OM", name: "Oman" },
  { code: "TR", name: "Turkey" },
  { code: "IQ", name: "Iraq" },
  { code: "IR", name: "Iran" },
  { code: "EG", name: "Egypt" },
  { code: "MA", name: "Morocco" },
  { code: "DZ", name: "Algeria" },
  { code: "TN", name: "Tunisia" },
  { code: "LY", name: "Libya" },
  { code: "SD", name: "Sudan" },
  { code: "NG", name: "Nigeria" },
  { code: "GH", name: "Ghana" },
  { code: "KE", name: "Kenya" },
  { code: "ZA", name: "South Africa" },
  { code: "CN", name: "China" },
  { code: "HK", name: "Hong Kong" },
  { code: "TW", name: "Taiwan" },
  { code: "JP", name: "Japan" },
  { code: "KR", name: "South Korea" },
  { code: "ID", name: "Indonesia" },
  { code: "MY", name: "Malaysia" },
  { code: "SG", name: "Singapore" },
  { code: "TH", name: "Thailand" },
  { code: "VN", name: "Vietnam" },
  { code: "PH", name: "Philippines" },
  { code: "MM", name: "Myanmar" },
  { code: "NP", name: "Nepal" },
  { code: "LK", name: "Sri Lanka" },
  { code: "US", name: "United States" },
  { code: "GB", name: "United Kingdom" },
  { code: "CA", name: "Canada" },
  { code: "AU", name: "Australia" },
  { code: "DE", name: "Germany" },
  { code: "FR", name: "France" },
  { code: "IT", name: "Italy" },
  { code: "ES", name: "Spain" },
  { code: "NL", name: "Netherlands" },
  { code: "SE", name: "Sweden" },
  { code: "NO", name: "Norway" },
  { code: "DK", name: "Denmark" },
  { code: "FI", name: "Finland" },
  { code: "RU", name: "Russia" },
  { code: "UA", name: "Ukraine" },
  { code: "BR", name: "Brazil" },
  { code: "MX", name: "Mexico" },
  { code: "AR", name: "Argentina" },
  { code: "CO", name: "Colombia" },
].sort((a, b) => a.name.localeCompare(b.name));
