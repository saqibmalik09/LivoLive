"use client";
import { useRouter } from "next/navigation";
import { listSelectablePeriods, periodLabel } from "@/lib/salary-hub/constants";
export function SalaryAuditPeriodPicker({ period }: { period: string }) {
  const router = useRouter();
  const periods = listSelectablePeriods(12);
  return (
    <div>
      <label className="text-[10px] font-black uppercase tracking-widest text-white/30 block mb-2">
        Period
      </label>
      <select
        value={period}
        onChange={(e) => {
          router.push(`/salary-audit?period=${encodeURIComponent(e.target.value)}`);
        }}
        className="bg-white/5 border border-white/10 rounded-xl px-4 py-3 font-bold min-w-[240px]"
      >
        {periods.map((id) => (
          <option key={id} value={id} className="bg-black">
            {periodLabel(id)} ({id})
          </option>
        ))}
      </select>
    </div>
  );
}
