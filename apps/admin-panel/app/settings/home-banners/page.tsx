import { supabaseAdmin } from "@/lib/supabase";
import { HomeBannersManager } from "@/components/HomeBannersManager";
import {
  getHomeTopBannerHeight,
  listPartyEventsForBannerLink,
  type HomeBannerRow,
} from "@/app/settings/home-banners/actions";
import { ArrowLeft, ImageIcon } from "lucide-react";
import Link from "next/link";
export const dynamic = "force-dynamic";
export const revalidate = 0;
export default async function HomeBannersSettingsPage() {
  const [{ data, error }, partyEvents, displayHeight] = await Promise.all([
    supabaseAdmin
      .from("banners")
      .select("*")
      .eq("placement", "top")
      .order("priority", { ascending: false })
      .order("created_at", { ascending: false }),
    listPartyEventsForBannerLink(),
    getHomeTopBannerHeight(),
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
        <div className="w-20 h-20 rounded-3xl bg-cyan-500/20 border border-cyan-500/20 flex items-center justify-center text-cyan-300">
          <ImageIcon size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Home Banners</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Top auto-scrolling banner carousel on the Home Hot tab. Set display height below, then
            upload images. Recommended upload size:{" "}
            <span className="text-amber-300 font-bold">1280×560px</span>. Link tap to a party event
            or a room ID.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Expected table <code className="text-amber-400">public.banners</code>.
          </p>
        </div>
      )}

      <HomeBannersManager
        items={(data ?? []) as HomeBannerRow[]}
        placement="top"
        partyEvents={partyEvents}
        initialDisplayHeight={displayHeight}
      />
    </div>
  );
}
