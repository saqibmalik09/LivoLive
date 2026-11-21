import { CdnImg } from "@/components/CdnImg";
import Link from "next/link";
import { Crown, Plus, Smile } from "lucide-react";
import { listRoomMicEmojisAdmin } from "@/app/settings/room-emojis/actions";
export default async function RoomEmojisPage() {
  const res = await listRoomMicEmojisAdmin();
  const emojis = res.emojis ?? [];
  return (
    <div className="space-y-10 pb-32">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-amber-400 to-orange-400 tracking-tighter">
            Room Mic Emojis
          </h1>
          <p className="text-white/60 mt-2 font-medium max-w-2xl">
            Free emojis for seated users. Mark premium to show only for VIP (vip_level &gt; 0). No
            coins charged when sent in room.
          </p>
        </div>

        <Link
          href="/settings/room-emojis/new"
          className="flex items-center gap-3 bg-gradient-to-r from-amber-500 to-orange-500 px-8 py-4 rounded-2xl text-black font-black uppercase tracking-widest hover:scale-105 transition-all"
        >
          <Plus size={20} /> New emoji
        </Link>
      </header>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {emojis.map((emoji) => (
          <Link
            key={emoji.id}
            href={`/settings/room-emojis/${emoji.id}`}
            className="glass-card group hover:border-amber-500/30 transition-all p-4 overflow-hidden relative"
          >
            <div className="aspect-square rounded-2xl bg-black/40 border border-white/5 overflow-hidden flex items-center justify-center relative mb-4">
              <CdnImg
                src={emoji.image_url}
                alt={emoji.name}
                className="w-4/5 h-4/5 object-contain group-hover:scale-110 transition-transform duration-500"
              />
              {emoji.is_premium && (
                <div className="absolute top-3 right-3 bg-amber-500/20 border border-amber-500/40 text-amber-300 px-2 py-1 rounded text-[8px] font-black uppercase tracking-widest flex items-center gap-1">
                  <Crown size={10} /> VIP
                </div>
              )}
              {!emoji.is_active && (
                <div className="absolute inset-0 bg-black/60 flex items-center justify-center text-xs font-black uppercase text-white/50">
                  Hidden
                </div>
              )}
            </div>
            <h3 className="font-black text-lg text-white/90">{emoji.name}</h3>
            <p className="text-[10px] text-white/30 uppercase tracking-widest mt-1">
              Order {emoji.sort_order}
            </p>
          </Link>
        ))}
      </div>

      {emojis.length === 0 && (
        <div className="py-32 text-center space-y-4">
          <div className="w-20 h-20 bg-white/5 rounded-full flex items-center justify-center mx-auto text-amber-500/30">
            <Smile size={40} />
          </div>
          <p className="text-white/40 font-medium">No mic emojis yet.</p>
          <Link
            href="/settings/room-emojis/new"
            className="inline-block text-amber-400 font-bold text-sm hover:underline"
          >
            Add first emoji →
          </Link>
        </div>
      )}
    </div>
  );
}
