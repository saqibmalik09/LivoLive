export type SalaryHubRole = "super_bd" | "bd_admin" | "bd" | "agency" | "host";
export const SALARY_HUB_ROLES: {
  id: SalaryHubRole;
  label: string;
}[] = [
  { id: "super_bd", label: "Super Admin" },
  { id: "bd_admin", label: "County Admin" },
  { id: "bd", label: "BD" },
  { id: "agency", label: "Agency" },
  { id: "host", label: "Host" },
];
export const ROLE_LABELS: Record<string, string> = {
  super_bd: "Super Admin",
  bd_admin: "County Admin",
  bd: "BD",
};
export const SALARY_HUB_PERIOD_COOKIE = "salary_hub_period";
export type PeriodPart = "A" | "B" | "W1" | "W2" | "W3" | "W4";
export const AGENCY_WEEKLY_CUTOVER = "2026-11-08";
const PERIOD_RE = /^(\d{4})-(\d{2})-(A|B|W[1-4])$/i;
function dayKey(year: number, month: number, day: number): string {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}
function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}
export function periodIdForDay(year: number, month: number, day: number): string {
  const part: PeriodPart =
    dayKey(year, month, day) >= AGENCY_WEEKLY_CUTOVER
      ? (`W${Math.min(4, Math.floor((day - 1) / 7) + 1)}` as PeriodPart)
      : day <= 15
        ? "A"
        : "B";
  return buildPeriodId(year, month, part);
}
export function currentPeriodId(date = new Date()): string {
  return periodIdForDay(date.getFullYear(), date.getMonth() + 1, date.getDate());
}
export function monthPeriodIds(year: number, month: number): string[] {
  const out: string[] = [];
  for (let day = 1; day <= daysInMonth(year, month); day++) {
    const id = periodIdForDay(year, month, day);
    if (!out.includes(id)) out.push(id);
  }
  return out;
}
function periodDayRange(p: { year: number; month: number; half: PeriodPart }): {
  startDay: number;
  endDay: number;
} {
  const last = daysInMonth(p.year, p.month);
  let startDay: number;
  let endDay: number;
  if (p.half === "A") {
    startDay = 1;
    endDay = 15;
  } else if (p.half === "B") {
    startDay = 16;
    endDay = last;
  } else {
    const week = Number(p.half.slice(1));
    startDay = 1 + 7 * (week - 1);
    endDay = week === 4 ? last : startDay + 6;
  }
  if (p.half === "A" || p.half === "B") {
    const cut = AGENCY_WEEKLY_CUTOVER;
    if (cut > dayKey(p.year, p.month, startDay) && cut <= dayKey(p.year, p.month, endDay)) {
      endDay = Number(cut.slice(8, 10)) - 1;
    }
  }
  return { startDay, endDay };
}
export function prevPeriodId(date = new Date()): string {
  const p = parsePeriodId(currentPeriodId(date))!;
  const { startDay } = periodDayRange(p);
  return currentPeriodId(new Date(p.year, p.month - 1, startDay - 1));
}
export function isValidPeriodId(periodId: string | null | undefined): boolean {
  return !!periodId && PERIOD_RE.test(periodId);
}
export function parsePeriodId(periodId: string): {
  year: number;
  month: number;
  half: PeriodPart;
} | null {
  const match = periodId.match(PERIOD_RE);
  if (!match) return null;
  return {
    year: Number(match[1]),
    month: Number(match[2]),
    half: match[3].toUpperCase() as PeriodPart,
  };
}
export function buildPeriodId(year: number, month: number, half: PeriodPart): string {
  return `${year}-${String(month).padStart(2, "0")}-${half}`;
}
export function periodDaysLabel(periodId: string): string {
  const p = parsePeriodId(periodId);
  if (!p) return "";
  const { startDay, endDay } = periodDayRange(p);
  return `${startDay}–${endDay === daysInMonth(p.year, p.month) ? "end" : endDay}`;
}
export function listSelectablePeriods(monthsBack = 18, date = new Date()): string[] {
  const out: string[] = [];
  const d = new Date(date.getFullYear(), date.getMonth(), 1);
  for (let i = 0; i < monthsBack; i++) {
    const y = d.getFullYear();
    const m = d.getMonth() + 1;
    out.push(...monthPeriodIds(y, m).reverse());
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
export function resolvePeriodId(fromUrl?: string | null, fromCookie?: string | null): string {
  if (isValidPeriodId(fromUrl)) return normalizePeriodId(fromUrl!);
  if (isValidPeriodId(fromCookie)) return normalizePeriodId(fromCookie!);
  return currentPeriodId();
}
export function periodBounds(periodId: string): {
  start: Date;
  end: Date;
} {
  const match = periodId.match(/^(\d{4})-(\d{2})-([ABH1]+|W[1-4])$/i);
  if (!match) {
    const now = new Date();
    return { start: now, end: now };
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const suffix = match[3].toUpperCase();
  const half: PeriodPart =
    suffix === "A" || suffix === "H1" ? "A" : suffix.startsWith("W") ? (suffix as PeriodPart) : "B";
  const { startDay, endDay } = periodDayRange({ year, month, half });
  return {
    start: new Date(year, month - 1, startDay, 0, 0, 0, 0),
    end: new Date(year, month - 1, endDay, 23, 59, 59, 999),
  };
}
export function periodLabel(periodId: string): string {
  const monthly = periodId.match(/^(\d{4})-(\d{2})-M$/i);
  if (monthly) {
    const monthName = new Date(Number(monthly[1]), Number(monthly[2]) - 1, 1).toLocaleString("en", {
      month: "short",
    });
    return `${monthName} ${monthly[1]} · Monthly`;
  }
  const p = parsePeriodId(periodId);
  if (!p) return periodId;
  const monthName = new Date(p.year, p.month - 1, 1).toLocaleString("en", {
    month: "short",
  });
  return `${monthName} ${p.year} · ${p.half} (${periodDaysLabel(periodId)})`;
}
export function withPeriod(href: string, period: string): string {
  const [path, query = ""] = href.split("?");
  const params = new URLSearchParams(query);
  params.set("period", period);
  const q = params.toString();
  return q ? `${path}?${q}` : path;
}
export function formatUsd(amount: number): string {
  return `$${Number(amount || 0).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })}`;
}
export function periodToBdMonth(periodId: string): string {
  const p = parsePeriodId(periodId);
  if (p) return p.half.startsWith("W") ? `${periodId.slice(0, 7)}-M` : buildPeriodId(p.year, p.month, p.half);
  const m = periodId.match(/^(\d{4}-\d{2})$/);
  return m ? m[1] : periodId.slice(0, 7);
}
export function periodToCalendarMonth(periodId: string): string {
  const m = periodId.match(/^(\d{4}-\d{2})/);
  return m ? m[1] : periodId.slice(0, 7);
}
