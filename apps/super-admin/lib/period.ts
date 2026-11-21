/** 15-day A/B period helpers (YYYY-MM-A / YYYY-MM-B). */

const PERIOD_RE = /^(\d{4})-(\d{2})-([ABM])$/i;

export const NETWORK_PERIOD_COOKIE = 'portal_network_period';

export type NetworkRole = 'county_admin' | 'bd' | 'agency' | 'host';

export const NETWORK_ROLES: { id: NetworkRole; label: string }[] = [
  { id: 'county_admin', label: 'Country Admin' },
  { id: 'bd', label: 'BD' },
  { id: 'agency', label: 'Agency' },
  { id: 'host', label: 'Host' },
];

export function currentPeriodId(date = new Date()): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  // One period per calendar month; the 15th no longer splits it.
  return `${y}-${m}-M`;
}

export function isValidPeriodId(periodId: string | null | undefined): boolean {
  return !!periodId && PERIOD_RE.test(periodId);
}

export function parsePeriodId(
  periodId: string,
): { year: number; month: number; half: 'A' | 'B' | 'M' } | null {
  const match = periodId.match(PERIOD_RE);
  if (!match) return null;
  return {
    year: Number(match[1]),
    month: Number(match[2]),
    half: match[3].toUpperCase() as 'A' | 'B' | 'M',
  };
}

export function buildPeriodId(year: number, month: number, half: 'A' | 'B' | 'M'): string {
  return `${year}-${String(month).padStart(2, '0')}-${half}`;
}

export function listSelectablePeriods(monthsBack = 12, date = new Date()): string[] {
  const out: string[] = [];
  const d = new Date(date.getFullYear(), date.getMonth(), 1);
  for (let i = 0; i < monthsBack; i++) {
    const y = d.getFullYear();
    const m = d.getMonth() + 1;
    out.push(buildPeriodId(y, m, 'M'));
    d.setMonth(d.getMonth() - 1);
  }
  return out;
}

function normalizePeriodId(periodId: string): string {
  const p = parsePeriodId(periodId);
  return p ? buildPeriodId(p.year, p.month, p.half) : currentPeriodId();
}

export function resolvePeriodId(fromUrl?: string | null, fromCookie?: string | null): string {
  if (isValidPeriodId(fromUrl)) return normalizePeriodId(fromUrl!);
  if (isValidPeriodId(fromCookie)) return normalizePeriodId(fromCookie!);
  return currentPeriodId();
}

export function periodLabel(periodId: string): string {
  const p = parsePeriodId(periodId);
  if (!p) return periodId;
  const month = new Date(p.year, p.month - 1, 1).toLocaleString('en', {
    month: 'short',
    year: 'numeric',
  });
  return `${month} · ${p.half === 'A' ? '1–15' : '16–end'}`;
}

export function withPeriod(href: string, period: string): string {
  const sep = href.includes('?') ? '&' : '?';
  return `${href}${sep}period=${encodeURIComponent(period)}`;
}
