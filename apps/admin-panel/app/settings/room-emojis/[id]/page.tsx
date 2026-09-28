import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { notFound } from "next/navigation";
import { RoomEmojiForm } from "@/components/RoomEmojiForm";
import { getRoomMicEmoji } from "@/app/settings/room-emojis/actions";
export default async function EditRoomEmojiPage({
  params,
}: {
  params: Promise<{
    id: string;
  }>;
}) {
  const { id } = await params;
  const res = await getRoomMicEmoji(id);
  if (!res.success || !res.emoji) notFound();
  return (
    <div className="space-y-8 pb-32">
      <Link
        href="/settings/room-emojis"
        className="inline-flex items-center gap-2 text-white/50 hover:text-white text-sm font-bold"
      >
        <ArrowLeft size={16} /> Back to emojis
      </Link>
      <h1 className="text-4xl font-black text-white">Edit: {res.emoji.name}</h1>
      <RoomEmojiForm emoji={res.emoji} />
    </div>
  );
}
