import { supabaseAdmin } from "@/lib/supabase";
import { PartyScreenBgForm } from "@/components/PartyScreenBgForm";
import { ArrowLeft, ImageIcon } from "lucide-react";
import Link from "next/link";
export default async function PartyScreenSettingsPage() {
  const { data: config, error } = await supabaseAdmin
    .from("party_screen_config")
    .select("*")
    .eq("id", 1)
    .maybeSingle();
  const topUrl = config?.top_image_url ?? "";
  const bottomUrl = config?.bottom_image_url ?? "";
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
        <div className="w-20 h-20 rounded-3xl bg-pink-500/20 border border-pink-500/20 flex items-center justify-center text-pink-400">
          <ImageIcon size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Party Screen Background</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Top and bottom bands for the Home (Party) screen. Center stays SK Live gradient in the
            app.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Run migration{" "}
            <code className="text-amber-400">20250630140000_party_screen_config.sql</code>
          </p>
        </div>
      )}

      <PartyScreenBgForm
        config={{
          top_image_url: topUrl,
          bottom_image_url: bottomUrl,
        }}
      />
    </div>
  );
}
