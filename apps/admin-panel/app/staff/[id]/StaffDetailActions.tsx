"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2 } from "lucide-react";
import { deactivateStaff } from "../actions";
export function StaffDetailActions({ staffId, isActive }: { staffId: string; isActive: boolean }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  async function handleDeactivate() {
    if (!confirm("Deactivate this staff member?")) return;
    setLoading(true);
    const res = await deactivateStaff(staffId);
    if (res.success) {
      router.refresh();
    } else {
      alert(res.error);
    }
    setLoading(false);
  }
  if (!isActive) {
    return <span className="text-red-400 font-bold text-sm">Inactive</span>;
  }
  return (
    <button
      onClick={handleDeactivate}
      disabled={loading}
      className="px-5 py-3 rounded-xl bg-red-500/20 text-red-300 font-bold text-sm hover:bg-red-500/30"
    >
      {loading ? <Loader2 className="animate-spin" size={16} /> : "Deactivate"}
    </button>
  );
}
