import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft, Smartphone, ShieldAlert } from "lucide-react";
import Link from "next/link";
import { VersionForm } from "./VersionForm";
export default async function AppVersionsPage() {
  const { data: versions } = await supabaseAdmin.from("app_versions").select("*");
  const androidVersion = versions?.find((v) => v.platform === "android");
  const iosVersion = versions?.find((v) => v.platform === "ios");
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
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-orange-400 to-amber-400 tracking-tighter">
          App Version Control
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Flutter opens the landing site URL; the landing Download button uses a separate Google
          Drive / APK link.
        </p>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="glass-card flex flex-col gap-6 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-green-500/10 to-transparent blur-3xl -mr-16 -mt-16 rounded-full" />

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-3 rounded-2xl bg-green-500/10 border border-green-500/20 text-green-400">
                <Smartphone size={24} />
              </div>
              <div>
                <h3 className="text-xl font-black">Android Client</h3>
                <p className="text-xs text-white/40 mt-0.5">Google Play / Side-loaded APK</p>
              </div>
            </div>
          </div>

          <div className="border-t border-white/5 my-2" />

          <VersionForm platform="android" initialData={androidVersion} />
        </div>

        <div className="glass-card flex flex-col gap-6 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-blue-500/10 to-transparent blur-3xl -mr-16 -mt-16 rounded-full" />

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-3 rounded-2xl bg-blue-500/10 border border-blue-500/20 text-blue-400">
                <Smartphone size={24} />
              </div>
              <div>
                <h3 className="text-xl font-black">iOS Client</h3>
                <p className="text-xs text-white/40 mt-0.5">App Store / TestFlight</p>
              </div>
            </div>
          </div>

          <div className="border-t border-white/5 my-2" />

          <VersionForm platform="ios" initialData={iosVersion} />
        </div>
      </div>
    </div>
  );
}
