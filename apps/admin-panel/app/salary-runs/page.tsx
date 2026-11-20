import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { ArrowLeft, Wallet } from "lucide-react";
import { SalaryRunsClient } from "./SalaryRunsClient";
import { getPeriodSalaryOverview } from "@/lib/salary-hub/queries";
import { currentPeriodId, prevPeriodId } from "@/lib/salary-hub/constants";
export default async function SalaryRunsPage() {
  const ids = [currentPeriodId(), prevPeriodId()];
  const { data: periods } = await supabaseAdmin
    .from("salary_periods")
    .select("*")
    .order("start_date", { ascending: false })
    .limit(12);
  const periodList = periods?.length
    ? periods
    : ids.map((id) => ({
        period_id: id,
        status: "open",
        start_date: id,
        end_date: id,
        payout_date: id,
      }));
  const firstPeriodId = periodList[0]?.period_id as string;
  const [{ data: payouts }, initialOverview] = await Promise.all([
    supabaseAdmin
      .from("host_salary_payouts")
      .select("*, users:beneficiary_user_id(username)")
      .in(
        "period_id",
        periodList.map((p) => p.period_id),
      )
      .order("created_at", { ascending: false }),
    firstPeriodId
      ? getPeriodSalaryOverview(firstPeriodId).catch(() => null)
      : Promise.resolve(null),
  ]);
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
      </Link>

      <div>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <Wallet size={48} className="text-emerald-500" />
          Salary Runs
        </h1>
        <p className="text-white/40 mt-2">
          Period select → Host + Agency + BD. Pay Host (diamonds), Pay Agency (USD), or Pay BD
          (USD).
        </p>
      </div>

      <SalaryRunsClient
        periods={periodList}
        payouts={payouts || []}
        initialOverview={initialOverview}
      />
    </div>
  );
}
