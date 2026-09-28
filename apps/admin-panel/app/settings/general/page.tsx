import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft, Users, Info, Link2 } from "lucide-react";
import Link from "next/link";
import { SettingRow } from "./SettingRow";
import { PaymentMethodManager } from "./PaymentMethodManager";
export default async function GeneralSettingsPage() {
  await supabaseAdmin.from("system_settings").upsert(
    {
      key: "invite_download_url",
      value: "https://sklive-sklive-landing.sin.app.zuvodev.com",
      description:
        "Invite Friends share link. Shown when users tap Invite / share their invitation code. No trailing slash.",
      updated_at: new Date().toISOString(),
    },
    { onConflict: "key", ignoreDuplicates: true },
  );
  const { data: settings } = await supabaseAdmin
    .from("system_settings")
    .select("*")
    .order("key", { ascending: true });
  const groups = [
    {
      title: "Social & Community",
      icon: Users,
      keys: ["family_creation_cost"],
      color: "text-blue-400",
    },
    {
      title: "Links & Sharing",
      icon: Link2,
      keys: ["invite_download_url", "room_share_base_url"],
      color: "text-amber-400",
    },
  ];
  return (
    <div className="space-y-12 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-indigo-400 to-blue-400 tracking-tighter">
          System Config
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Manage global constants and platform behavior
        </p>
      </header>

      <div className="space-y-8">
        {groups.map((group) => (
          <div key={group.title} className="space-y-4">
            <div className="flex items-center gap-3 px-2">
              <group.icon size={20} className={group.color} />
              <h2 className="text-sm font-black uppercase tracking-widest text-white/80">
                {group.title}
              </h2>
            </div>

            <div className="glass-card divide-y divide-white/5 p-0 overflow-hidden">
              {settings
                ?.filter((s) => group.keys.includes(s.key))
                .map((setting) => (
                  <SettingRow key={setting.key} setting={setting} />
                ))}
              {settings?.filter((s) => group.keys.includes(s.key)).length === 0 && (
                <div className="p-8 text-center text-white/20 text-xs italic">
                  No settings found in this category.
                </div>
              )}
            </div>
          </div>
        ))}

        <div className="space-y-4">
          <div className="flex items-center gap-3 px-2">
            <Info size={20} className="text-white/40" />
            <h2 className="text-sm font-black uppercase tracking-widest text-white/40">
              Other Settings
            </h2>
          </div>
          <div className="glass-card divide-y divide-white/5 p-0 overflow-hidden">
            {settings
              ?.filter(
                (s) => !groups.some((g) => g.keys.includes(s.key)) && s.key !== "game_control_mode",
              )
              .map((setting) => (
                <SettingRow key={setting.key} setting={setting} />
              ))}
          </div>
        </div>

        <PaymentMethodManager
          initialMethods={JSON.parse(
            settings?.find((s) => s.key === "payment_methods")?.value ||
              '["Binance", "JazzCash", "Bank Transfer"]',
          )}
        />
      </div>
    </div>
  );
}
