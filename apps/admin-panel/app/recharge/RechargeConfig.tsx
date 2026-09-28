"use client";
import { useState } from "react";
import {
  Plus,
  Trash2,
  Smartphone,
  Save,
  Loader2,
  Coins,
  ArrowLeft,
  MoreVertical,
} from "lucide-react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { addRechargePackage, deleteRechargePackage, updateRechargePackage } from "./actions";
interface RechargePackage {
  id: string;
  beans_amount: number;
  price_usd: number;
  play_store_id: string;
  is_active: boolean;
  sort_order: number;
}
export default function RechargeConfigPage({ packages }: { packages: RechargePackage[] }) {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);
  const handleDelete = async (id: string) => {
    if (!confirm("Delete this package?")) return;
    setLoading(id);
    const res = await deleteRechargePackage(id);
    if (!res.success) alert(res.error);
    else router.refresh();
    setLoading(null);
  };
  const toggleStatus = async (pkg: RechargePackage) => {
    setLoading(pkg.id);
    const res = await updateRechargePackage(pkg.id, { is_active: !pkg.is_active });
    if (!res.success) alert(res.error);
    else router.refresh();
    setLoading(null);
  };
  return (
    <div className="space-y-10 pb-32">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group mb-2"
          >
            <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
            <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
          </Link>
          <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
            <Coins size={48} className="text-amber-400" />
            Wallet Packages
          </h1>
          <p className="text-white/40 font-medium max-w-xl">
            Define the bean bundles users can purchase via Google Play In-App Purchases.
          </p>
        </div>

        <button
          onClick={() => {
            const beans = prompt("Beans Amount?");
            const price = prompt("Price (USD)?");
            const playId = prompt("Play Store Product ID?");
            if (beans && price && playId) {
              addRechargePackage({
                beans_amount: parseInt(beans),
                price_usd: parseFloat(price),
                play_store_id: playId,
                is_active: true,
              }).then((res) => {
                if (res.success) router.refresh();
                else alert(res.error);
              });
            }
          }}
          className="px-8 py-4 bg-amber-400 hover:bg-amber-300 text-black font-black rounded-2xl transition-all flex items-center gap-3 shadow-xl shadow-amber-400/10 active:scale-95"
        >
          <Plus size={20} />
          Create New Package
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {packages.map((pkg) => (
          <div
            key={pkg.id}
            className={`glass-card p-8 group relative overflow-hidden transition-all ${!pkg.is_active ? "opacity-50 grayscale" : ""}`}
          >
            <div className="flex justify-between items-start mb-6">
              <div className="w-12 h-12 rounded-2xl bg-amber-400/20 flex items-center justify-center">
                <Coins className="text-amber-400" size={24} />
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => toggleStatus(pkg)}
                  className={`p-2 rounded-lg transition-all ${pkg.is_active ? "text-emerald-400 bg-emerald-400/10" : "text-white/20 bg-white/5"}`}
                >
                  {loading === pkg.id ? (
                    <Loader2 className="animate-spin" size={18} />
                  ) : (
                    <Smartphone size={18} />
                  )}
                </button>
                <button
                  onClick={() => handleDelete(pkg.id)}
                  className="p-2 text-red-500/40 hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-all"
                >
                  <Trash2 size={18} />
                </button>
              </div>
            </div>

            <div className="space-y-6">
              <div>
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                  Package Size
                </p>
                <p className="text-4xl font-black tracking-tighter text-white">
                  {pkg.beans_amount.toLocaleString()}{" "}
                  <span className="text-xs uppercase text-amber-400 tracking-widest ml-1">
                    Beans
                  </span>
                </p>
              </div>

              <div className="p-4 bg-white/5 rounded-2xl border border-white/5">
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                  Play Store Product ID
                </p>
                <p className="text-sm font-mono text-amber-400/80 truncate">{pkg.play_store_id}</p>
              </div>

              <div className="pt-4 border-t border-white/5 flex items-end justify-between">
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                    Price
                  </p>
                  <p className="text-3xl font-black text-white">${pkg.price_usd}</p>
                </div>
                <div
                  className={`px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest ${pkg.is_active ? "bg-emerald-500/20 text-emerald-400" : "bg-white/10 text-white/30"}`}
                >
                  {pkg.is_active ? "Active" : "Hidden"}
                </div>
              </div>
            </div>
          </div>
        ))}

        {packages.length === 0 && (
          <div className="col-span-full py-32 glass-card flex flex-col items-center justify-center text-center space-y-4 border-dashed border-white/10">
            <div className="w-20 h-20 rounded-full bg-white/5 flex items-center justify-center">
              <Coins size={40} className="text-white/10" />
            </div>
            <div>
              <h3 className="text-xl font-bold">No Packages Found</h3>
              <p className="text-white/40 text-sm">
                Start by creating your first recharge package above.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
