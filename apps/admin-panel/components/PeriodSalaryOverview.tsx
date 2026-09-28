import Link from "next/link";
import { AmountValue } from "@/components/AmountValue";
import type { PeriodSalaryOverview } from "@/lib/salary-hub/types";
import { formatUsd, periodLabel } from "@/lib/salary-hub/constants";
export function PeriodSalaryOverviewPanel({
  overview,
  hubLinks = true,
}: {
  overview: PeriodSalaryOverview;
  hubLinks?: boolean;
}) {
  const period = overview.periodId;
  const Card = hubLinks ? Link : "div";
  return (
    <section className="glass-card p-6 space-y-5 border-emerald-500/20">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-[10px] font-black uppercase tracking-widest text-emerald-400/80">
            Period overview
          </p>
          <h2 className="text-2xl font-black tracking-tight">{periodLabel(period)}</h2>
          <p className="text-xs text-white/40 mt-1">
            BD period {overview.bdMonth} · Super Admin {overview.staff.superBd} · County{" "}
            {overview.staff.countyAdmin} · BD staff {overview.staff.bd}
          </p>
        </div>
        <div className="text-right">
          <AmountValue
            value={formatUsd(overview.grandEstimatedUsd)}
            size="lg"
            className="text-emerald-300"
          />
          <p className="text-[9px] uppercase tracking-widest text-white/35 mt-1">
            Grand est · Host + Agency + BD
          </p>
          <p className="text-sm text-white/45 mt-1">Paid {formatUsd(overview.grandPaidUsd)}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <OverviewCard
          as={Card}
          href={hubLinks ? `/salary-hub?role=host&period=${period}` : undefined}
          title="Host"
          est={overview.hosts.estimatedUsd}
          paid={overview.hosts.paidUsd}
          meta={`${overview.hosts.withProgress} active · ${overview.hosts.paidRows} paid rows · ${overview.hosts.count} stats`}
          accent="text-blue-300"
        />
        <OverviewCard
          as={Card}
          href={hubLinks ? `/salary-hub?role=agency&period=${period}` : undefined}
          title="Agency"
          est={overview.agencies.estimatedUsd}
          paid={overview.agencies.paidUsd}
          meta={`${overview.agencies.withLevel} leveled · ${overview.agencies.paidRows} paid · ${overview.agencies.count} agencies`}
          accent="text-pink-300"
        />
        <OverviewCard
          as={Card}
          href={hubLinks ? `/salary-hub?role=bd&period=${period}` : undefined}
          title={`BD (${overview.bdMonth})`}
          est={overview.bd.estimatedUsd}
          paid={overview.bd.paidUsd}
          meta={`${overview.bd.withLevel} leveled · ${overview.bd.paidRows} paid · monthly`}
          accent="text-amber-300"
        />
        <OverviewCard
          as={Card}
          href={hubLinks ? `/salary-hub?role=super_bd&period=${period}` : undefined}
          title="Super / County"
          est={null}
          paid={null}
          meta={`No flat salary — open staff in Hub for tree Host $ + Agency $. ${overview.staff.superBd + overview.staff.countyAdmin} staff`}
          accent="text-emerald-300/80"
          headline={`${overview.staff.superBd + overview.staff.countyAdmin} staff`}
        />
      </div>
    </section>
  );
}
function OverviewCard({
  as: Comp,
  href,
  title,
  est,
  paid,
  meta,
  accent,
  headline,
}: {
  as: typeof Link | "div";
  href?: string;
  title: string;
  est: number | null;
  paid: number | null;
  meta: string;
  accent: string;
  headline?: string;
}) {
  const className =
    "rounded-xl bg-black/35 border border-white/10 p-4 hover:border-emerald-500/30 transition-colors";
  const body = (
    <>
      <p className={`text-[10px] font-black uppercase tracking-widest ${accent}`}>{title}</p>
      {headline ? (
        <p className="text-lg font-black mt-2">{headline}</p>
      ) : (
        <>
          <AmountValue value={formatUsd(est || 0)} size="md" className="text-white mt-2" />
          <p className="text-[9px] uppercase tracking-widest text-white/30 mt-1">Est.</p>
          <p className="text-sm text-white/50 mt-2">Paid {formatUsd(paid || 0)}</p>
        </>
      )}
      <p className="text-[11px] text-white/35 mt-2 leading-snug">{meta}</p>
    </>
  );
  if (Comp === Link && href) {
    return (
      <Link href={href} className={className}>
        {body}
      </Link>
    );
  }
  return <div className={className}>{body}</div>;
}
