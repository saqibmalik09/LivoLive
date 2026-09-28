"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Wallet } from "lucide-react";
import { payOneAgency, payOneBd } from "@/app/salary-hub/pay-actions";
import { formatUsd } from "@/lib/salary-hub/constants";
type Props =
  | {
      kind: "agency";
      periodId: string;
      entityId: string;
      label?: string;
      amountUsd?: number;
      alreadyPaid?: boolean;
      disabled?: boolean;
      className?: string;
    }
  | {
      kind: "bd";
      periodId: string;
      entityId: string;
      label?: string;
      amountUsd?: number;
      alreadyPaid?: boolean;
      disabled?: boolean;
      className?: string;
    };
export function SalaryEntityPayButton(props: Props) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const paid = props.alreadyPaid === true;
  const disabled = props.disabled || paid || loading;
  async function onPay(e: React.MouseEvent) {
    e.preventDefault();
    e.stopPropagation();
    if (disabled) return;
    const who = props.label || (props.kind === "agency" ? "agency" : "BD");
    const amt =
      props.amountUsd != null && props.amountUsd > 0 ? ` (~${formatUsd(props.amountUsd)})` : "";
    if (!confirm(`Pay ${who}${amt}?\n\nUSD goes to their cash wallet.`)) {
      return;
    }
    setLoading(true);
    const res =
      props.kind === "agency"
        ? await payOneAgency(props.periodId, props.entityId)
        : await payOneBd(props.periodId, props.entityId);
    setLoading(false);
    if (!res.success) {
      alert(res.error);
      return;
    }
    const d = (res.data ?? {}) as Record<string, unknown>;
    if (d.already_paid) {
      alert("Already paid.");
    } else {
      const usd = d.total_usd != null ? formatUsd(Number(d.total_usd)) : "OK";
      alert(`Paid ${usd} to cash wallet.`);
    }
    router.refresh();
  }
  if (paid) {
    return (
      <span
        className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest bg-emerald-500/15 text-emerald-300 ${props.className ?? ""}`}
      >
        Paid
      </span>
    );
  }
  return (
    <button
      type="button"
      onClick={onPay}
      disabled={disabled}
      className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest text-black disabled:opacity-40 disabled:cursor-not-allowed ${
        props.kind === "bd" ? "bg-sky-500 hover:bg-sky-400" : "bg-pink-500 hover:bg-pink-400"
      } ${props.className ?? ""}`}
    >
      {loading ? <Loader2 size={12} className="animate-spin" /> : <Wallet size={12} />}
      Pay
    </button>
  );
}
