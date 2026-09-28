import { supabaseAdmin } from "@/lib/supabase";
import { RoomDecorationForm } from "@/components/RoomDecorationForm";
import { ArrowLeft, Palette } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
export default async function EditRoomDecorationPage({
  params,
}: {
  params: Promise<{
    id: string;
  }>;
}) {
  const { id } = await params;
  const { data: item } = await supabaseAdmin
    .from("room_decorations")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (!item) notFound();
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings/room-decorations"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-indigo-500/20 flex items-center justify-center text-indigo-400">
          <Palette size={40} />
        </div>
        <h1 className="text-5xl font-black tracking-tighter">Edit: {item.name}</h1>
      </header>

      <RoomDecorationForm item={item} />
    </div>
  );
}
