"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  updateBottomNavItem,
  uploadBottomNavIcon,
  type BottomNavKey,
} from "@/app/settings/bottom-nav/actions";
import { Loader2, Upload, CheckCircle2, Image as ImageIcon } from "lucide-react";
const SCREEN_LABELS: Record<BottomNavKey, string> = {
  home: "PartyScreen (Home tab)",
  party: "SocialDiscoverScreen (Party tab)",
  game: "RupeeGameScreen (Game tab)",
  message: "MessagesScreen",
  my: "MyProfileScreen",
};
interface BottomNavItemFormProps {
  item: {
    nav_key: BottomNavKey;
    label: string;
    icon_url: string;
    active_icon_url?: string | null;
    focus_overlay_url?: string | null;
    is_active: boolean;
    sort_order: number;
  };
}
export function BottomNavItemForm({ item }: BottomNavItemFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [iconUrl, setIconUrl] = useState(item.icon_url || "");
  const [activeIconUrl, setActiveIconUrl] = useState(item.active_icon_url || "");
  const [focusOverlayUrl, setFocusOverlayUrl] = useState(item.focus_overlay_url || "");
  const [uploading, setUploading] = useState<string | null>(null);
  const iconInputRef = useRef<HTMLInputElement>(null);
  const activeInputRef = useRef<HTMLInputElement>(null);
  const focusInputRef = useRef<HTMLInputElement>(null);
  async function handleUpload(
    e: React.ChangeEvent<HTMLInputElement>,
    variant: "icon" | "active" | "focus",
  ) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(variant);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("nav_key", item.nav_key);
    formData.append("variant", variant);
    const res = await uploadBottomNavIcon(formData);
    if (res.success && res.url) {
      if (variant === "icon") setIconUrl(res.url);
      if (variant === "active") setActiveIconUrl(res.url);
      if (variant === "focus") setFocusOverlayUrl(res.url);
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
    const formData = new FormData(e.currentTarget);
    const res = await updateBottomNavItem({
      nav_key: item.nav_key,
      label: formData.get("label") as string,
      icon_url: iconUrl,
      active_icon_url: activeIconUrl || null,
      focus_overlay_url: focusOverlayUrl || null,
      is_active: formData.get("is_active") === "on",
    });
    if (res.success) {
      router.refresh();
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  return (
    <form onSubmit={handleSubmit} className="glass-card p-6 space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <span className="text-[10px] font-black uppercase tracking-widest text-amber-500/70">
            {item.nav_key}
          </span>
          <h3 className="text-xl font-black mt-1">{SCREEN_LABELS[item.nav_key]}</h3>
          <p className="text-white/40 text-xs mt-1">Sort order: {item.sort_order}</p>
        </div>
        <label className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-white/50">
          <input
            type="checkbox"
            name="is_active"
            defaultChecked={item.is_active}
            className="rounded accent-amber-500"
          />
          Active
        </label>
      </div>

      <div>
        <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
          Tab label
        </label>
        <input
          name="label"
          defaultValue={item.label}
          required
          className="mt-2 w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-500/50"
        />
      </div>

      <AssetField
        label="Default icon"
        hint="Shown when tab is inactive. Leave empty to use bundled app asset."
        url={iconUrl}
        onUrlChange={setIconUrl}
        uploading={uploading === "icon"}
        onUploadClick={() => iconInputRef.current?.click()}
      />
      <input
        ref={iconInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => handleUpload(e, "icon")}
      />

      <AssetField
        label="Active icon (optional)"
        hint="If set, replaces default icon + focus overlay when selected."
        url={activeIconUrl}
        onUrlChange={setActiveIconUrl}
        uploading={uploading === "active"}
        onUploadClick={() => activeInputRef.current?.click()}
      />
      <input
        ref={activeInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => handleUpload(e, "active")}
      />

      <AssetField
        label="Focus overlay (optional)"
        hint="Glow behind icon when active. Default: app bundled focus.png"
        url={focusOverlayUrl}
        onUrlChange={setFocusOverlayUrl}
        uploading={uploading === "focus"}
        onUploadClick={() => focusInputRef.current?.click()}
      />
      <input
        ref={focusInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => handleUpload(e, "focus")}
      />

      <button
        type="submit"
        disabled={loading}
        className="w-full flex items-center justify-center gap-2 bg-amber-500 text-black font-black uppercase tracking-widest py-4 rounded-2xl hover:scale-[1.02] transition-all disabled:opacity-50"
      >
        {loading ? <Loader2 size={18} className="animate-spin" /> : "Save tab"}
      </button>
    </form>
  );
}
function AssetField({
  label,
  hint,
  url,
  onUrlChange,
  uploading,
  onUploadClick,
}: {
  label: string;
  hint: string;
  url: string;
  onUrlChange: (v: string) => void;
  uploading: boolean;
  onUploadClick: () => void;
}) {
  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest flex items-center gap-2">
          <ImageIcon size={10} /> {label}
        </label>
        {url && <CheckCircle2 size={12} className="text-emerald-500" />}
      </div>
      <p className="text-[11px] text-white/30">{hint}</p>
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
          className="px-4 py-3 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all"
        >
          {uploading ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
        </button>
      </div>
      {url ? (
        <div className="h-16 w-16 rounded-xl bg-black/40 border border-white/5 flex items-center justify-center p-2">
          <CdnImg src={url} alt="" className="max-h-full max-w-full object-contain" />
        </div>
      ) : null}
    </div>
  );
}
