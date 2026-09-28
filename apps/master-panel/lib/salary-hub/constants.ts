export type SalaryHubRole =
  | 'super_bd'
  | 'bd_admin'
  | 'bd'
  | 'agency'
  | 'host';

export const SALARY_HUB_ROLES: { id: SalaryHubRole; label: string }[] = [
  { id: 'super_bd', label: 'Super Admin' },
  { id: 'bd_admin', label: 'County Admin' },
  { id: 'bd', label: 'BD' },
  { id: 'agency', label: 'Agency' },
  { id: 'host', label: 'Host' },
];

export const ROLE_LABELS: Record<string, string> = {
  super_bd: 'Super Admin',
  bd_admin: 'County Admin',
  county_admin: 'County Admin',
  bd: 'BD',
  assistant: 'Assistant',
  customer_service: 'Customer Service',
};

export const SALARY_HUB_PERIOD_COOKIE = 'salary_hub_period';

const PERIOD_RE = /^(\d{4})-(\d{2})-([AB])$/i;

/** Current 15-day period id: YYYY-MM-A (1–15) or YYYY-MM-B (16–end). */
export function currentPeriodId(date = new Date()): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const day = date.getDate();
  return day <= 15 ? `${y}-${m}-A` : `${y}-${m}-B`;
}

export function prevPeriodId(date = new Date()): string {
  const d = new Date(date);
  if (d.getDate() <= 15) {
    d.setMonth(d.getMonth() - 1);
    d.setDate(20);
  } else {
    d.setDate(1);
  }
  return currentPeriodId(d);
}

export function isValidPeriodId(periodId: string | null | undefined): boolean {
  return !!periodId && PERIOD_RE.test(periodId);
}

export function parsePeriodId(
  periodId: string,
): { year: number; month: number; half: 'A' | 'B' } | null {
  const match = periodId.match(PERIOD_RE);
  if (!match) return null;
  return {
    year: Number(match[1]),
    month: Number(match[2]),
    half: match[3].toUpperCase() as 'A' | 'B',
  };
}

export function buildPeriodId(
  year: number,
  month: number,
  half: 'A' | 'B',
): string {
  return `${year}-${String(month).padStart(2, '0')}-${half}`;
}

/** Last `monthsBack` calendar months × A/B, newest first. */
export function listSelectablePeriods(
  monthsBack = 18,
  date = new Date(),
): string[] {
  const out: string[] = [];
  const d = new Date(date.getFullYear(), date.getMonth(), 1);
  for (let i = 0; i < monthsBack; i++) {
    const y = d.getFullYear();
    const m = d.getMonth() + 1;
    out.push(buildPeriodId(y, m, 'B'));
    out.push(buildPeriodId(y, m, 'A'));
    d.setMonth(d.getMonth() - 1);
  }
  return out;
}

export function periodOptions(date = new Date()): string[] {
  return listSelectablePeriods(18, date);
}

function normalizePeriodId(periodId: string): string {
  const p = parsePeriodId(periodId);
  return p ? buildPeriodId(p.year, p.month, p.half) : currentPeriodId();
}

/** Prefer URL period, then cookie, then current. */
export function resolvePeriodId(
  fromUrl?: string | null,
  fromCookie?: string | null,
): string {
  if (isValidPeriodId(fromUrl)) return normalizePeriodId(fromUrl!);
  if (isValidPeriodId(fromCookie)) return normalizePeriodId(fromCookie!);
  return currentPeriodId();
}

export function periodBounds(periodId: string): { start: Date; end: Date } {
  const match = periodId.match(/^(\d{4})-(\d{2})-([ABH1]+)$/i);
  if (!match) {
    const now = new Date();
    return { start: now, end: now };
  }
  const year = Number(match[1]);
  const month = Number(match[2]) - 1;
  const suffix = match[3].toUpperCase();
  const isA = suffix === 'A' || suffix === 'H1';
  if (isA) {
    return {
      start: new Date(year, month, 1, 0, 0, 0, 0),
      end: new Date(year, month, 15, 23, 59, 59, 999),
    };
  }
  return {
    start: new Date(year, month, 16, 0, 0, 0, 0),
    end: new Date(year, month + 1, 0, 23, 59, 59, 999),
  };
}

export function periodLabel(periodId: string): string {
  const p = parsePeriodId(periodId);
  if (!p) return periodId;
  const monthName = new Date(p.year, p.month - 1, 1).toLocaleString('en', {
    month: 'short',
  });
  return `${monthName} ${p.year} · ${p.half} (${p.half === 'A' ? '1–15' : '16–end'})`;
}

export function withPeriod(href: string, period: string): string {
  const [path, query = ''] = href.split('?');
  const params = new URLSearchParams(query);
  params.set('period', period);
  const q = params.toString();
  return q ? `${path}?${q}` : path;
}

export function formatUsd(amount: number): string {
  return `$${Number(amount || 0).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })}`;
}

/**
 * BD settlement key — same half-period as agency/host (`YYYY-MM-A|B`).
 * Legacy bare `YYYY-MM` kept as-is for old monthly rows.
 */
export function periodToBdMonth(periodId: string): string {
  const p = parsePeriodId(periodId);
  if (p) return buildPeriodId(p.year, p.month, p.half);
  const m = periodId.match(/^(\d{4}-\d{2})$/);
  return m ? m[1] : periodId.slice(0, 7);
}

/** Calendar month `YYYY-MM` from hub/BD period (for leadership monthly audits). */
export function periodToCalendarMonth(periodId: string): string {
  const m = periodId.match(/^(\d{4}-\d{2})/);
  return m ? m[1] : periodId.slice(0, 7);
}
