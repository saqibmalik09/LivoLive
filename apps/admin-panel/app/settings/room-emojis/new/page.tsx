import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { RoomEmojiForm } from "@/components/RoomEmojiForm";
export default function NewRoomEmojiPage() {
  return (
    <div className="space-y-8 pb-32">
      <Link
        href="/settings/room-emojis"
        className="inline-flex items-center gap-2 text-white/50 hover:text-white text-sm font-bold"
      >
        <ArrowLeft size={16} /> Back to emojis
      </Link>
      <h1 className="text-4xl font-black text-white">New mic emoji</h1>
      <RoomEmojiForm />
    </div>
  );
}
