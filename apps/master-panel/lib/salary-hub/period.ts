import { cookies } from 'next/headers';
import {
  SALARY_HUB_PERIOD_COOKIE,
  resolvePeriodId,
} from '@/lib/salary-hub/constants';

/** Resolve period from URL or Salary Hub cookie (one picker → everywhere). */
export async function getHubPeriod(
  fromUrl?: string | null,
): Promise<string> {
  const jar = await cookies();
  const fromCookie = jar.get(SALARY_HUB_PERIOD_COOKIE)?.value ?? null;
  return resolvePeriodId(fromUrl, fromCookie);
}
