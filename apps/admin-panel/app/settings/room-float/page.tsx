import { supabaseAdmin } from "@/lib/supabase";
import { RoomSideFloatManager } from "@/components/RoomSideFloatManager";
import {
  listGamesForFloatLink,
  listPartyEventsForFloatLink,
} from "@/app/settings/room-float/actions";
import { ArrowLeft, LayoutPanelLeft } from "lucide-react";
import Link from "next/link";
export default async function RoomFloatSettingsPage() {
  const [{ data: items, error }, partyEvents, games] = await Promise.all([
    supabaseAdmin
      .from("room_side_float_items")
      .select("*")
      .order("kind", { ascending: true })
      .order("sort_order", { ascending: true }),
    listPartyEventsForFloatLink(),
    listGamesForFloatLink(),
  ]);
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
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-400">
          <LayoutPanelLeft size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Room Float Icons</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Square icons on the live room right-bottom rail. Games cycle on top, events below.
            Prefer murba (1:1) images; wide banners are cropped to square in the app.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Run{" "}
            <code className="text-amber-400">node scripts/apply-room-side-float-migration.mjs</code>{" "}
            from sk-live-admin.
          </p>
        </div>
      )}

      <RoomSideFloatManager
        items={
          (items as Record<string, unknown>[])?.map((row) => ({
            id: String(row.id),
            kind: (row.kind === "game" ? "game" : "event") as "event" | "game",
            title: String(row.title ?? ""),
            image_url: String(row.image_url ?? ""),
            party_event_id: row.party_event_id ? String(row.party_event_id) : null,
            game_slug: row.game_slug ? String(row.game_slug) : null,
            sort_order: Number(row.sort_order ?? 0),
            is_active: Boolean(row.is_active ?? true),
          })) ?? []
        }
        partyEvents={
          partyEvents as {
            id: string;
            title: string;
            banner_url?: string | null;
            is_active?: boolean;
          }[]
        }
        games={
          games as {
            slug: string;
            name: string;
            icon_url?: string | null;
            is_active?: boolean;
          }[]
        }
      />
    </div>
  );
}
