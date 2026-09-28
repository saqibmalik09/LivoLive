"use client";
import { useState } from "react";
import { Check, X, Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { approveHost, rejectHost } from "./actions";
export function HostActions({ id }: { id: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);
  async function handle(action: "approve" | "reject") {
    setLoading(action);
    const res = action === "approve" ? await approveHost(id) : await rejectHost(id);
    if (res.success) {
      router.refresh();
    } else {
      alert(res.error);
    }
    setLoading(null);
  }
  return (
    <div className="flex items-center gap-2">
      <button
        onClick={() => handle("approve")}
        disabled={!!loading}
        className="p-3 bg-emerald-500 text-black rounded-xl hover:scale-105 transition-all disabled:opacity-50"
      >
        {loading === "approve" ? (
          <Loader2 size={18} className="animate-spin" />
        ) : (
          <Check size={18} />
        )}
      </button>
      <button
        onClick={() => handle("reject")}
        disabled={!!loading}
        className="p-3 bg-red-500/10 border border-red-500/20 text-red-500 rounded-xl hover:bg-red-500 hover:text-black transition-all disabled:opacity-50"
      >
        {loading === "reject" ? <Loader2 size={18} className="animate-spin" /> : <X size={18} />}
      </button>
    </div>
  );
}
