"use client";
import { useState } from "react";
import { updateUserApplicationStatus, updateAgencyApplicationStatus } from "./actions";
import { Check, X, Loader2, AlertCircle } from "lucide-react";
import { useRouter } from "next/navigation";
interface ApplicationActionsProps {
  id: string;
  status: string;
  type: "agency" | "host";
}
export function ApplicationActions({ id, status, type }: ApplicationActionsProps) {
  const router = useRouter();
  const [loading, setLoading] = useState<"approved" | "rejected" | null>(null);
  if (status !== "pending") {
    return (
      <div className="flex items-center gap-3 p-6 rounded-2xl bg-white/5 border border-white/5">
        <AlertCircle size={18} className="text-white/20" />
        <p className="text-sm font-medium text-white/40">
          This application has already been processed and is now{" "}
          <span className="text-white uppercase font-black tracking-widest text-[10px]">
            {status}
          </span>
          .
        </p>
      </div>
    );
  }
  async function handleUpdate(newStatus: "approved" | "rejected") {
    setLoading(newStatus);
    const res =
      type === "agency"
        ? await updateUserApplicationStatus(id, newStatus)
        : await updateAgencyApplicationStatus(id, newStatus);
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
        onClick={() => handleUpdate("approved")}
        disabled={!!loading}
        className="flex-1 w-full py-6 bg-emerald-500 hover:bg-emerald-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 shadow-xl shadow-emerald-500/10 active:scale-95 disabled:opacity-50"
      >
        {loading === "approved" ? (
          <Loader2 size={24} className="animate-spin" />
        ) : (
          <Check size={24} />
        )}
        Approve & Finalize
      </button>

      <button
        onClick={() => handleUpdate("rejected")}
        disabled={!!loading}
        className="flex-1 w-full py-6 bg-red-500/10 border border-red-500/20 hover:bg-red-500 text-red-500 hover:text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 active:scale-95 disabled:opacity-50"
      >
        {loading === "rejected" ? <Loader2 size={24} className="animate-spin" /> : <X size={24} />}
        Reject Application
      </button>
    </div>
  );
}
