"use client";
import { useState } from "react";
import { saveAppVersion } from "./actions";
import { Loader2, Save, CheckCircle } from "lucide-react";
interface VersionFormProps {
  platform: "android" | "ios";
  initialData?: {
    min_version: string;
    download_url: string;
    apk_download_url?: string | null;
    is_force_update: boolean;
  };
}
export function VersionForm({ platform, initialData }: VersionFormProps) {
  const [minVersion, setMinVersion] = useState(initialData?.min_version || "1.0.0");
  const [landingSiteUrl, setLandingSiteUrl] = useState(
    initialData?.download_url || "https://rave-land.vercel.app",
  );
  const [apkDownloadUrl, setApkDownloadUrl] = useState(initialData?.apk_download_url || "");
  const [isForceUpdate, setIsForceUpdate] = useState(initialData?.is_force_update ?? true);
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setSuccess(false);
    const res = await saveAppVersion(
      platform,
      minVersion,
      landingSiteUrl,
      isForceUpdate,
      apkDownloadUrl,
    );
    if (res.success) {
      if (res.downloadUrl) setLandingSiteUrl(res.downloadUrl);
      if (res.apkDownloadUrl != null) setApkDownloadUrl(res.apkDownloadUrl);
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } else {
      alert(`Error saving version: ${res.error}`);
    }
    setSaving(false);
  };
  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-white/30 uppercase tracking-[0.2em] block">
          Minimum Required Version
        </label>
        <input
          type="text"
          value={minVersion}
          onChange={(e) => setMinVersion(e.target.value)}
          placeholder="e.g. 1.1.2+6"
          required
          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-orange-500/50 transition-all text-white placeholder:text-white/20"
        />
        <p className="text-[11px] text-white/30">
          Format: major.minor.patch+build (e.g. <code className="text-orange-400">1.1.2+6</code>).
          App versions below this will be blocked.
        </p>
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-white/30 uppercase tracking-[0.2em] block">
          Landing Site URL (Flutter button)
        </label>
        <input
          type="url"
          value={landingSiteUrl}
          onChange={(e) => setLandingSiteUrl(e.target.value)}
          placeholder="https://rave-land.vercel.app"
          required
          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-orange-500/50 transition-all text-white placeholder:text-white/20"
        />
        <p className="text-[11px] text-white/30 leading-relaxed">
          Flutter app update / download button opens this website (your landing page), not the APK
          file.
        </p>
      </div>

      {platform === "android" && (
        <div className="space-y-2">
          <label className="text-[10px] font-bold text-white/30 uppercase tracking-[0.2em] block">
            APK / Google Drive URL (Landing download button)
          </label>
          <input
            type="url"
            value={apkDownloadUrl}
            onChange={(e) => setApkDownloadUrl(e.target.value)}
            placeholder="https://drive.google.com/file/d/FILE_ID/view?usp=sharing"
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-orange-500/50 transition-all text-white placeholder:text-white/20"
          />
          <p className="text-[11px] text-white/30 leading-relaxed">
            Used only on the landing page Download button. Paste a Google Drive share link (Anyone
            with the link) — it is converted to a direct download.
          </p>
        </div>
      )}

      <div className="flex items-center gap-3 bg-white/[0.02] border border-white/5 rounded-2xl p-4">
        <input
          type="checkbox"
          id={`force-update-${platform}`}
          checked={isForceUpdate}
          onChange={(e) => setIsForceUpdate(e.target.checked)}
          className="w-5 h-5 rounded border-white/10 bg-black/40 text-orange-500 focus:ring-0 focus:ring-offset-0 cursor-pointer"
        />
        <label htmlFor={`force-update-${platform}`} className="cursor-pointer select-none">
          <span className="text-sm font-bold block text-white/90">Force Immediate Update</span>
          <span className="text-xs text-white/40 block mt-0.5">
            If checked, blocks the application screen entirely until updated.
          </span>
        </label>
      </div>

      <div className="flex items-center gap-4 mt-8">
        <button
          type="submit"
          disabled={saving}
          className="flex-1 py-4 bg-gradient-to-r from-orange-500 to-amber-500 text-black font-black text-xs uppercase tracking-widest rounded-xl hover:opacity-95 transition-all disabled:opacity-50 active:scale-95 flex items-center justify-center gap-2"
        >
          {saving ? <Loader2 size={16} className="animate-spin text-black" /> : <Save size={16} />}
          {saving ? "Saving..." : "Save Settings"}
        </button>

        {success && (
          <div className="flex items-center gap-2 text-emerald-400 text-xs font-bold bg-emerald-500/10 border border-emerald-500/20 px-4 py-3.5 rounded-xl">
            <CheckCircle size={16} />
            Saved!
          </div>
        )}
      </div>
    </form>
  );
}
