"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  updatePartyScreenConfig,
  uploadPartyScreenImage,
} from "@/app/settings/party-screen/actions";
import { Loader2, Upload, CheckCircle2, Image as ImageIcon } from "lucide-react";
interface PartyScreenBgFormProps {
  config: {
    top_image_url: string;
    bottom_image_url: string;
  };
}
export function PartyScreenBgForm({ config }: PartyScreenBgFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [topUrl, setTopUrl] = useState(config.top_image_url || "");
  const [bottomUrl, setBottomUrl] = useState(config.bottom_image_url || "");
  const [uploading, setUploading] = useState<"top" | "bottom" | null>(null);
  const topInputRef = useRef<HTMLInputElement>(null);
  const bottomInputRef = useRef<HTMLInputElement>(null);
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>, variant: "top" | "bottom") {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(variant);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("variant", variant);
    const res = await uploadPartyScreenImage(formData);
    if (res.success && res.url) {
      if (variant === "top") setTopUrl(res.url);
      else setBottomUrl(res.url);
      router.refresh();
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
    }
    setUploading(null);
    e.target.value = "";
  }
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const res = await updatePartyScreenConfig({
      top_image_url: topUrl,
      bottom_image_url: bottomUrl,
    });
    if (res.success) {
      router.refresh();
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  return (
    <form onSubmit={handleSubmit} className="space-y-8">
      <p className="text-white/50 text-sm max-w-2xl">
        Middle section uses the app gradient in code. Upload top (app bar / stadium) and bottom
        (grass / bottom nav area) images only.
      </p>

      <BandField
        label="Top band (app bar area)"
        hint="Stadium / header artwork — blends into gold gradient below"
        url={topUrl}
        onUrlChange={setTopUrl}
        uploading={uploading === "top"}
        onUploadClick={() => topInputRef.current?.click()}
        previewHeight="h-32"
      />
      <input
        ref={topInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => handleUpload(e, "top")}
      />

      <BandField
        label="Bottom band (bottom nav area)"
        hint="Grass / field artwork — blends into gradient above"
        url={bottomUrl}
        onUrlChange={setBottomUrl}
        uploading={uploading === "bottom"}
        onUploadClick={() => bottomInputRef.current?.click()}
        previewHeight="h-28"
      />
      <input
        ref={bottomInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => handleUpload(e, "bottom")}
      />

      <button
        type="submit"
        disabled={loading}
        className="w-full max-w-md flex items-center justify-center gap-2 bg-amber-500 text-black font-black uppercase tracking-widest py-4 rounded-2xl hover:scale-[1.02] transition-all disabled:opacity-50"
      >
        {loading ? <Loader2 size={18} className="animate-spin" /> : "Save URLs"}
      </button>
    </form>
  );
}
function BandField({
  label,
  hint,
  url,
  onUrlChange,
  uploading,
  onUploadClick,
  previewHeight,
}: {
  label: string;
  hint: string;
  url: string;
  onUrlChange: (v: string) => void;
  uploading: boolean;
  onUploadClick: () => void;
  previewHeight: string;
}) {
  return (
    <div className="glass-card p-6 space-y-4">
      <div className="flex items-center justify-between">
        <label className="text-sm font-bold uppercase tracking-widest text-white/70 flex items-center gap-2">
          <ImageIcon size={14} /> {label}
        </label>
        {url && <CheckCircle2 size={14} className="text-emerald-500" />}
      </div>
      <p className="text-xs text-white/40">{hint}</p>
      <div className="flex gap-2">
        <input
          value={url}
          onChange={(e) => onUrlChange(e.target.value)}
          placeholder="https://..."
          className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-xs font-mono focus:outline-none focus:border-amber-500/50"
        />
        <button
          type="button"
          onClick={onUploadClick}
          disabled={uploading}
          className="px-4 py-3 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10"
        >
          {uploading ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
        </button>
      </div>
      {url ? (
        <div
          className={`w-full ${previewHeight} rounded-xl overflow-hidden bg-black/40 border border-white/5`}
        >
          <img src={url} alt="" className="w-full h-full object-cover" />
        </div>
      ) : null}
    </div>
  );
}
