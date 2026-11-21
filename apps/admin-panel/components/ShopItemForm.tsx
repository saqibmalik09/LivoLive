"use client";
import { CdnImg } from "@/components/CdnImg";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { upsertShopItem, deleteShopItem, uploadFile } from "@/app/shop/actions";
import { SvgaPreview } from "@/components/SvgaPreview";
import { MediaDropPasteZone } from "@/components/MediaDropPasteZone";
import { publicMediaUrl, storageThumbUrl } from "@/lib/media-url";
import {
  Save,
  Trash2,
  Loader2,
  Image as ImageIcon,
  Sparkles,
  Clock,
  Coins,
  ShieldCheck,
  Zap,
  CheckCircle2,
} from "lucide-react";
interface ShopItemFormProps {
  item?: any;
  categories: any[];
}
export function ShopItemForm({ item, categories }: ShopItemFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [imageUrl, setImageUrl] = useState(item?.image_url || "");
  const [svgaUrl, setSvgaUrl] = useState(item?.svga_url || "");
  const [svgaPreviewSrc, setSvgaPreviewSrc] = useState(item?.svga_url || "");
  const [svgaPreviewKey, setSvgaPreviewKey] = useState(Date.now());
  const [previewMode, setPreviewMode] = useState<"image" | "svga">(
    item?.svga_url ? "svga" : "image",
  );
  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadingSvga, setUploadingSvga] = useState(false);
  const svgaBlobRef = useRef<string | null>(null);
  useEffect(() => {
    return () => {
      if (svgaBlobRef.current?.startsWith("blob:")) {
        URL.revokeObjectURL(svgaBlobRef.current);
      }
    };
  }, []);
  async function uploadMedia(file: File, type: "image" | "svga") {
    if (type === "image") {
      setUploadingImage(true);
    } else {
      setUploadingSvga(true);
      if (svgaBlobRef.current?.startsWith("blob:")) {
        URL.revokeObjectURL(svgaBlobRef.current);
      }
      const localUrl = URL.createObjectURL(file);
      svgaBlobRef.current = localUrl;
      setSvgaPreviewSrc(localUrl);
      setSvgaPreviewKey(Date.now());
      setPreviewMode("svga");
    }
    const formData = new FormData();
    formData.append("file", file);
    const res = await uploadFile(formData);
    if (res.success && res.url) {
      if (type === "image") {
        setImageUrl(res.url);
        setPreviewMode("image");
      } else {
        setSvgaUrl(res.url);
        setSvgaPreviewSrc(svgaBlobRef.current || res.url);
        setSvgaPreviewKey(Date.now());
        setPreviewMode("svga");
      }
    } else {
      alert("Upload failed: " + res.error);
    }
    if (type === "image") setUploadingImage(false);
    else setUploadingSvga(false);
  }
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const formData = new FormData(e.currentTarget);
    const data = {
      id: item?.id,
      name: formData.get("name"),
      description: formData.get("description"),
      category_id: formData.get("category_id"),
      price_coins: parseInt(formData.get("price_coins") as string),
      duration_days: parseInt(formData.get("duration_days") as string),
      image_url: imageUrl,
      svga_url: svgaUrl,
      sound_url: formData.get("sound_url"),
      is_active: formData.get("is_active") === "on",
      is_for_sale: formData.get("is_for_sale") === "on",
      is_gift: formData.get("is_gift") === "on",
      is_full_screen: formData.get("is_full_screen") === "on",
      required_vip_level: parseInt((formData.get("required_vip_level") as string) || "0"),
      required_wealth_value: parseInt((formData.get("required_wealth_value") as string) || "0"),
      source_type: formData.get("source_type"),
    };
    const res = await upsertShopItem(data);
    if (res.success) {
      router.push("/shop");
      router.refresh();
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  async function handleDelete() {
    if (!confirm("Are you sure you want to delete this item? This action cannot be undone."))
      return;
    setDeleting(true);
    const res = await deleteShopItem(item.id);
    if (res.success) {
      router.push("/shop");
      router.refresh();
    } else {
      alert("Error: " + res.error);
    }
    setDeleting(false);
  }
  const showSvgaPreview = previewMode === "svga" && Boolean(svgaPreviewSrc || svgaUrl);
  return (
    <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-3 gap-12">
      <div className="lg:col-span-1 space-y-8">
        <div className="glass-card overflow-hidden p-0">
          <div className="aspect-square bg-black/60 flex items-center justify-center border-b border-white/5 relative group">
            {showSvgaPreview ? (
              <div className="absolute inset-4 overflow-hidden rounded-xl">
                <SvgaPreview
                  key={svgaPreviewKey}
                  src={publicMediaUrl(svgaPreviewSrc || svgaUrl)}
                  className="absolute inset-0 h-full w-full"
                />
              </div>
            ) : imageUrl ? (
              <CdnImg
                src={storageThumbUrl(imageUrl, 480)}
                alt="Preview"
                referrerPolicy="no-referrer"
                onError={(e) => {
                  const full = publicMediaUrl(imageUrl);
                  if (full && e.currentTarget.src !== full) e.currentTarget.src = full;
                }}
                className="w-4/5 h-4/5 object-contain"
              />
            ) : (
              <ImageIcon size={64} className="text-white/10" />
            )}

            {(imageUrl || svgaUrl || svgaPreviewSrc) && (
              <div className="absolute top-3 left-3 flex gap-2 z-20">
                <button
                  type="button"
                  onClick={() => setPreviewMode("image")}
                  className={`px-2.5 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider ${
                    previewMode === "image"
                      ? "bg-amber-500 text-black"
                      : "bg-black/60 text-white/70 border border-white/10"
                  }`}
                >
                  Image
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewMode("svga")}
                  disabled={!svgaUrl && !svgaPreviewSrc}
                  className={`px-2.5 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider disabled:opacity-40 ${
                    previewMode === "svga"
                      ? "bg-blue-500 text-white"
                      : "bg-black/60 text-white/70 border border-white/10"
                  }`}
                >
                  SVGA
                </button>
              </div>
            )}

            {(uploadingImage || uploadingSvga) && (
              <div className="absolute inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-30">
                <Loader2 size={32} className="animate-spin text-amber-500" />
              </div>
            )}
          </div>

          <div className="p-8 space-y-8">
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
                  <ImageIcon size={10} /> Product Image
                </label>
                {imageUrl && <CheckCircle2 size={12} className="text-emerald-500" />}
              </div>
              <MediaDropPasteZone
                accept="image/*"
                label="Drop or paste image"
                hint="Drag & drop · Ctrl/⌘ V · click browse"
                uploading={uploadingImage}
                disabled={uploadingSvga}
                accent="amber"
                onFile={(file) => uploadMedia(file, "image")}
              />
              <input
                name="image_url"
                value={imageUrl}
                onChange={(e) => setImageUrl(e.target.value)}
                placeholder="Or paste image URL https://..."
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-500/50 transition-all text-xs font-mono"
              />
            </div>

            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
                  <Sparkles size={10} /> SVGA Animation
                </label>
                {svgaUrl && <CheckCircle2 size={12} className="text-blue-500" />}
              </div>
              <MediaDropPasteZone
                accept=".svga,application/octet-stream"
                label="Drop SVGA file"
                hint="Drag & drop · click browse"
                uploading={uploadingSvga}
                disabled={uploadingImage}
                accent="blue"
                onFile={(file) => uploadMedia(file, "svga")}
              />
              <input
                name="svga_url"
                value={svgaUrl}
                onChange={(e) => {
                  setSvgaUrl(e.target.value);
                  setSvgaPreviewSrc(e.target.value);
                  setSvgaPreviewKey(Date.now());
                  if (e.target.value) setPreviewMode("svga");
                }}
                placeholder="Or paste SVGA URL https://.../.svga"
                className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-blue-500/50 transition-all text-xs font-mono"
              />
              {(svgaPreviewSrc || svgaUrl) && (
                <p className="text-[10px] text-blue-300/80">
                  SVGA plays in the preview above — switch Image / SVGA tabs to compare.
                </p>
              )}
            </div>
          </div>
        </div>

        <div className="flex flex-col gap-4">
          <button
            type="submit"
            disabled={loading || uploadingImage || uploadingSvga}
            className="w-full py-5 bg-amber-500 hover:bg-amber-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 shadow-xl shadow-amber-500/10 active:scale-95 disabled:opacity-50"
          >
            {loading ? <Loader2 size={24} className="animate-spin" /> : <Save size={24} />}
            {item ? "Save Changes" : "Create Shop Item"}
          </button>

          {item && (
            <button
              type="button"
              onClick={handleDelete}
              disabled={deleting}
              className="w-full py-5 bg-red-500/10 border border-red-500/20 hover:bg-red-500 text-red-500 hover:text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 active:scale-95 disabled:opacity-50"
            >
              {deleting ? <Loader2 size={24} className="animate-spin" /> : <Trash2 size={24} />}
              Delete Item
            </button>
          )}
        </div>
      </div>

      <div className="lg:col-span-2 space-y-8">
        <div className="glass-card space-y-8 p-10">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                Item Name
              </label>
              <input
                required
                name="name"
                defaultValue={item?.name}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all font-bold text-xl"
              />
            </div>

            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                Category
              </label>
              <select
                required
                name="category_id"
                defaultValue={item?.category_id}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all font-bold text-lg appearance-none"
              >
                <option value="">Select Category</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
              Description
            </label>
            <textarea
              name="description"
              defaultValue={item?.description}
              rows={4}
              className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all text-sm"
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 pt-4">
            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
                <Coins size={10} /> Price (Coins)
              </label>
              <input
                required
                type="number"
                name="price_coins"
                defaultValue={item?.price_coins || 0}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all font-mono text-2xl font-black"
              />
            </div>

            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
                <Clock size={10} /> Duration (Days)
              </label>
              <input
                required
                type="number"
                name="duration_days"
                defaultValue={item?.duration_days || 7}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all font-mono text-2xl font-black"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-6">
            <div className="flex items-center justify-between p-6 rounded-2xl bg-white/5 border border-white/5">
              <div className="space-y-1">
                <h4 className="text-sm font-bold flex items-center gap-2">
                  <Zap size={14} className="text-emerald-500" /> Active Status
                </h4>
                <p className="text-[10px] text-white/30 uppercase font-black tracking-widest">
                  Visible in store
                </p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  name="is_active"
                  defaultChecked={item?.is_active ?? true}
                  className="sr-only peer"
                />
                <div className="w-14 h-7 bg-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white/40 after:border-white/10 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-emerald-600 peer-checked:after:bg-white peer-checked:after:border-transparent"></div>
              </label>
            </div>

            <div className="flex items-center justify-between p-6 rounded-2xl bg-white/5 border border-white/5">
              <div className="space-y-1">
                <h4 className="text-sm font-bold flex items-center gap-2">
                  <Coins size={14} className="text-amber-500" /> For Sale
                </h4>
                <p className="text-[10px] text-white/30 uppercase font-black tracking-widest">
                  Can be purchased
                </p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  name="is_for_sale"
                  defaultChecked={item?.is_for_sale ?? true}
                  className="sr-only peer"
                />
                <div className="w-14 h-7 bg-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white/40 after:border-white/10 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-amber-600 peer-checked:after:bg-white peer-checked:after:border-transparent"></div>
              </label>
            </div>

            <div className="flex items-center justify-between p-6 rounded-2xl bg-white/5 border border-white/5">
              <div className="space-y-1">
                <h4 className="text-sm font-bold flex items-center gap-2">
                  <Sparkles size={14} className="text-purple-500" /> Gift Mode
                </h4>
                <p className="text-[10px] text-white/30 uppercase font-black tracking-widest">
                  Show in gift panel
                </p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  name="is_gift"
                  defaultChecked={item?.is_gift ?? false}
                  className="sr-only peer"
                />
                <div className="w-14 h-7 bg-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white/40 after:border-white/10 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-purple-600 peer-checked:after:bg-white peer-checked:after:border-transparent"></div>
              </label>
            </div>

            <div className="flex items-center justify-between p-6 rounded-2xl bg-white/5 border border-white/5">
              <div className="space-y-1">
                <h4 className="text-sm font-bold flex items-center gap-2">
                  <Zap size={14} className="text-blue-500" /> Full Screen
                </h4>
                <p className="text-[10px] text-white/30 uppercase font-black tracking-widest">
                  Special Animation
                </p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  name="is_full_screen"
                  defaultChecked={item?.is_full_screen ?? false}
                  className="sr-only peer"
                />
                <div className="w-14 h-7 bg-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white/40 after:border-white/10 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-blue-600 peer-checked:after:bg-white peer-checked:after:border-transparent"></div>
              </label>
            </div>
          </div>
        </div>

        <div className="glass-card p-10 space-y-8">
          <div className="flex items-center gap-3">
            <ShieldCheck className="text-blue-400" />
            <h3 className="text-lg font-black tracking-tight uppercase">
              Entitlement Requirements
            </h3>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                Min. VIP Level
              </label>
              <input
                type="number"
                name="required_vip_level"
                defaultValue={item?.required_vip_level || 0}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-blue-500/50 transition-all font-mono"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                Min. Wealth Value
              </label>
              <input
                type="number"
                name="required_wealth_value"
                defaultValue={item?.required_wealth_value || 0}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-blue-500/50 transition-all font-mono"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                Source Type
              </label>
              <select
                name="source_type"
                defaultValue={item?.source_type || "shop"}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-blue-500/50 transition-all font-bold appearance-none"
              >
                <option value="shop">Regular Shop</option>
                <option value="vip">VIP Reward</option>
                <option value="medal">Medal Requirement</option>
                <option value="event">Special Event</option>
              </select>
            </div>
          </div>
        </div>
      </div>
    </form>
  );
}
