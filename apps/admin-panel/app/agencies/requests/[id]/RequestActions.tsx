"use client";
import { useState } from "react";
import { Check, X, Loader2, AlertCircle } from "lucide-react";
import { useRouter } from "next/navigation";
import { approveAgencyRequest, rejectAgencyRequest } from "./actions";
interface RequestActionsProps {
  id: string;
  status: string;
  userId: string;
  realName: string;
}
export function RequestActions({ id, status, userId, realName }: RequestActionsProps) {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);
  if (status !== "pending") {
    return (
      <div className="flex items-center gap-3 p-6 rounded-2xl bg-white/5 border border-white/5">
        <AlertCircle size={18} className="text-white/20" />
        <p className="text-sm font-medium text-white/40">
          This request has been{" "}
          <span className="text-white uppercase font-black tracking-widest text-[10px]">
            {status}
          </span>
          .
        </p>
      </div>
    );
  }
  async function handle(action: "approve" | "reject") {
    setLoading(action);
    const res =
      action === "approve"
        ? await approveAgencyRequest(id, userId, realName)
        : await rejectAgencyRequest(id);
    if (res.success) {
      router.refresh();
    } else {
      alert(res.error);
    }
    setLoading(null);
  }
  return (
    <div className="flex flex-col md:flex-row items-center gap-6">
      <button
        onClick={() => handle("approve")}
        disabled={!!loading}
        className="flex-1 w-full py-6 bg-emerald-500 hover:bg-emerald-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 shadow-xl shadow-emerald-500/10 active:scale-95 disabled:opacity-50"
      >
        {loading === "approve" ? (
          <Loader2 size={24} className="animate-spin" />
        ) : (
          <Check size={24} />
        )}
        Approve & Create Agency
      </button>
      <button
        onClick={() => handle("reject")}
        disabled={!!loading}
        className="flex-1 w-full py-6 bg-red-500/10 border border-red-500/20 hover:bg-red-500 text-red-500 hover:text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 active:scale-95 disabled:opacity-50"
      >
        {loading === "reject" ? <Loader2 size={24} className="animate-spin" /> : <X size={24} />}
        Reject
      </button>
    </div>
  );
}
