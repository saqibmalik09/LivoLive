import { supabaseAdmin } from "@/lib/supabase";
import { BottomNavItemForm } from "@/components/BottomNavItemForm";
import { ArrowLeft, LayoutGrid } from "lucide-react";
import Link from "next/link";
import type { BottomNavKey } from "@/app/settings/bottom-nav/actions";
export default async function BottomNavSettingsPage() {
  const { data: items, error } = await supabaseAdmin
    .from("bottom_nav_items")
    .select("*")
    .order("sort_order", { ascending: true });
  const ordered = (items ?? []).sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
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
          <LayoutGrid size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Bottom Navigation</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Manage tab labels and icons for the mobile app. Four fixed tabs: Home, Party, Message,
            My. Icons upload to <code className="text-amber-400/80">app_assets/bottom-nav/</code>.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error.message}</p>
          <p className="mt-3 text-white/50">
            Supabase SQL Editor mein migration run karo:{" "}
            <code className="text-amber-400">20250630120000_bottom_nav_items.sql</code>
          </p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {ordered.map((item) => (
          <BottomNavItemForm
            key={item.id}
            item={{
              nav_key: item.nav_key as BottomNavKey,
              label: item.label,
              icon_url: item.icon_url ?? "",
              active_icon_url: item.active_icon_url,
              focus_overlay_url: item.focus_overlay_url,
              is_active: item.is_active ?? true,
              sort_order: item.sort_order ?? 0,
            }}
          />
        ))}
      </div>

      {ordered.length === 0 && (
        <p className="text-white/40 text-center py-12">
          No bottom nav rows found. Run the Supabase migration{" "}
          <code className="text-amber-400">20250630120000_bottom_nav_items.sql</code>.
        </p>
      )}
    </div>
  );
}
