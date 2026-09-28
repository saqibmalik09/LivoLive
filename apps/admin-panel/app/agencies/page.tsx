import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { SALARY_HUB_PERIOD_COOKIE, resolvePeriodId } from "@/lib/salary-hub/constants";
export default async function AgenciesPageRedirect({
  searchParams,
}: {
  searchParams: Promise<{
    period?: string;
  }>;
}) {
  const sp = await searchParams;
  const jar = await cookies();
  const period = resolvePeriodId(sp.period, jar.get(SALARY_HUB_PERIOD_COOKIE)?.value ?? null);
  redirect(`/salary-hub?role=agency&period=${period}`);
}
