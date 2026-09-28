import { supabaseAdmin } from "@/lib/supabase";
import { PartyEventsManager } from "@/components/PartyEventsManager";
import {
  listGiftItemsForCpEvent,
  listGameConfigsForGameStar,
  listShopItemsForPartyEventRewards,
} from "@/app/settings/party-events/actions";
import { ArrowLeft, CalendarDays } from "lucide-react";
import Link from "next/link";
export default async function PartyEventsSettingsPage() {
  const [{ data: events, error }, giftItems, gameConfigs, shopItems] = await Promise.all([
    supabaseAdmin
      .from("party_events")
      .select("*")
      .order("priority", { ascending: false })
      .order("created_at", { ascending: false }),
    listGiftItemsForCpEvent(),
    listGameConfigsForGameStar(),
    listShopItemsForPartyEventRewards(),
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
        <div className="w-20 h-20 rounded-3xl bg-sky-500/20 border border-sky-500/20 flex items-center justify-center text-sky-400">
          <CalendarDays size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Party Events</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Event cards on the Home → Events tab. Upload banners, set dates, and choose which screen
            opens when users tap a card.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          {error.message}
          <p className="mt-2 text-white/50">
            Run migration 20250701140000_party_events.sql on Supabase if the table is missing.
          </p>
        </div>
      )}

      <PartyEventsManager
        events={(events as Record<string, unknown>[]) ?? []}
        giftItems={giftItems}
        gameConfigs={gameConfigs}
        shopItems={shopItems}
      />
    </div>
  );
}
