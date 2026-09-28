import { supabaseAdmin } from "@/lib/supabase";
import { CustomBackgroundPriceForm } from "@/components/CustomBackgroundPriceForm";
import { ArrowLeft, Plus, Palette } from "lucide-react";
import Link from "next/link";
export default async function RoomDecorationsPage() {
  const [{ data: decorations }, { data: priceSetting }] = await Promise.all([
    supabaseAdmin
      .from("room_decorations")
      .select("*")
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: false }),
    supabaseAdmin
      .from("system_settings")
      .select("value")
      .eq("key", "room_custom_background_price")
      .maybeSingle(),
  ]);
  const customPrice = parseInt(priceSetting?.value ?? "500", 10) || 0;
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div className="flex items-center gap-6">
          <div className="w-20 h-20 rounded-3xl bg-indigo-500/20 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
            <Palette size={40} />
          </div>
          <div>
            <h1 className="text-5xl font-black tracking-tighter">Room Decorations</h1>
            <p className="text-white/60 mt-2 font-medium max-w-xl">
              Image ya SVGA — dono alag alag upload ho sakte hain. Catalog free/premium; users app
              se photo ya SVGA upload kar sakte hain.
            </p>
          </div>
        </div>
        <Link
          href="/settings/room-decorations/new"
          className="flex items-center gap-3 bg-indigo-500 px-8 py-4 rounded-2xl text-black font-black uppercase tracking-widest hover:scale-105 transition-all"
        >
          <Plus size={20} /> Add background
        </Link>
      </header>

      <CustomBackgroundPriceForm initialPrice={customPrice} />

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {decorations?.map((d) => (
          <Link
            key={d.id}
            href={`/settings/room-decorations/${d.id}`}
            className="glass-card overflow-hidden group hover:border-indigo-500/30 transition-all"
          >
            <div className="aspect-[9/16] max-h-48 mx-auto bg-black/40 relative">
              {d.image_url ? (
                <img
                  src={d.image_url}
                  alt={d.name}
                  className="w-full h-full object-cover opacity-80 group-hover:opacity-100 transition-opacity"
                />
              ) : d.svga_url ? (
                <div className="w-full h-full flex flex-col items-center justify-center gap-2 text-blue-300/70 bg-gradient-to-b from-indigo-950/40 to-black/60">
                  <Palette size={28} className="opacity-60" />
                  <span className="text-[10px] font-black uppercase tracking-widest">SVGA</span>
                </div>
              ) : (
                <div className="w-full h-full flex items-center justify-center text-white/20">
                  No image
                </div>
              )}
              {!d.is_active && (
                <span className="absolute top-2 right-2 px-2 py-1 rounded-lg bg-red-500/80 text-[10px] font-black uppercase">
                  Hidden
                </span>
              )}
              {d.svga_url && (
                <span className="absolute top-2 left-2 px-2 py-1 rounded-lg bg-blue-500/80 text-[10px] font-black uppercase">
                  SVGA
                </span>
              )}
            </div>
            <div className="p-4 space-y-1">
              <h3 className="font-bold truncate">{d.name}</h3>
              <p className="text-xs text-white/40">
                {d.is_premium && (d.price ?? 0) > 0 ? `${d.price} coins` : "Free"}
                {" · "}Order {d.sort_order ?? 0}
              </p>
            </div>
          </Link>
        ))}
        {(!decorations || decorations.length === 0) && (
          <p className="text-white/30 col-span-full text-center py-12">
            No catalog decorations yet. Add backgrounds from S3/storage URLs or upload here.
          </p>
        )}
      </div>
    </div>
  );
}
