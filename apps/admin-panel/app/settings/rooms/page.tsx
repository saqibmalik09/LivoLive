import { listAdminRooms, type AdminRoomRow } from "@/app/settings/rooms/actions";
import { RoomBannerManager } from "@/components/RoomBannerManager";
import { ArrowLeft, Home } from "lucide-react";
import Link from "next/link";
export default async function RoomBannersSettingsPage() {
  let rooms: AdminRoomRow[] = [];
  let error: string | null = null;
  try {
    rooms = await listAdminRooms(80);
  } catch (e: any) {
    error = e?.message ?? "Failed to load rooms";
  }
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-sky-500/20 border border-sky-500/20 flex items-center justify-center text-sky-300">
          <Home size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Room Banners</h1>
          <p className="text-white/60 mt-2 font-medium max-w-2xl">
            Change room card banner and live background for any host room. Search by title or room
            ID, upload a new image, and save.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">{error}</div>
      )}

      <RoomBannerManager initialRooms={rooms} />
    </div>
  );
}
