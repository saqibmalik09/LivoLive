import Link from "next/link";
import { ArrowLeft, ShieldAlert } from "lucide-react";
import { loadMaintenanceSettings } from "./actions";
import { MaintenanceForm } from "./MaintenanceForm";
export const dynamic = "force-dynamic";
export default async function MaintenanceSettingsPage() {
  const settings = await loadMaintenanceSettings();
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="group inline-flex items-center gap-2 text-white/40 transition-colors hover:text-white"
      >
        <ArrowLeft size={18} className="transition-transform group-hover:-translate-x-1" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header className="space-y-2">
        <div className="flex items-center gap-3">
          <ShieldAlert className="text-amber-300" size={28} />
          <h1 className="bg-gradient-to-r from-amber-300 to-orange-400 bg-clip-text text-5xl font-black tracking-tighter text-transparent">
            Maintenance
          </h1>
        </div>
        <p className="max-w-2xl text-white/55">
          Takes the whole app down. The mobile app shows a blocking screen and the realtime gateway
          drops every connection, so nobody can enter or stay in a room. Only a debug build carrying
          the gateway bypass token gets through.
        </p>
      </header>

      {settings.enabled && (
        <div className="rounded-2xl border border-amber-400/40 bg-amber-500/10 px-5 py-4 text-sm font-bold text-amber-200">
          Maintenance is currently ON — the app is down for all users.
        </div>
      )}

      <MaintenanceForm initial={settings} />
    </div>
  );
}
