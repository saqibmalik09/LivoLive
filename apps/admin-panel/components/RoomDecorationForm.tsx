"use client";
import { CdnImg } from "@/components/CdnImg";
import { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  upsertRoomDecoration,
  deleteRoomDecoration,
  uploadRoomDecorationImage,
  uploadRoomDecorationSvga,
} from "@/app/settings/room-decorations/actions";
import {
  Save,
  Trash2,
  Loader2,
  Upload,
  CheckCircle2,
  Coins,
  Palette,
  Sparkles,
  Image as ImageIcon,
} from "lucide-react";
type MediaKind = "image" | "svga";
interface RoomDecorationFormProps {
  item?: {
    id: string;
    name: string;
    image_url: string | null;
    svga_url?: string | null;
    is_premium: boolean;
    price: number;
    is_active: boolean;
    sort_order: number;
  };
}
function inferMediaKind(item?: RoomDecorationFormProps["item"]): MediaKind {
  const hasSvga = Boolean(item?.svga_url?.trim());
  const hasImage = Boolean(item?.image_url?.trim());
  if (hasSvga && !hasImage) return "svga";
  if (hasSvga) return "svga";
  return "image";
}
export function RoomDecorationForm({ item }: RoomDecorationFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState("");
  const [name, setName] = useState(item?.name || "");
  const [sortOrder, setSortOrder] = useState(String(item?.sort_order ?? 0));
  const [price, setPrice] = useState(String(item?.price ?? 0));
  const [isActive, setIsActive] = useState(item?.is_active ?? true);
  const [mediaKind, setMediaKind] = useState<MediaKind>(() => inferMediaKind(item));
  const [imageUrl, setImageUrl] = useState(item?.image_url || "");
  const [svgaUrl, setSvgaUrl] = useState(item?.svga_url || "");
  const [isPremium, setIsPremium] = useState(item?.is_premium ?? false);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadingSvga, setUploadingSvga] = useState(false);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const svgaInputRef = useRef<HTMLInputElement>(null);
  async function handleFileUpload(e: React.ChangeEvent<HTMLInputElement>, type: "image" | "svga") {
    const file = e.target.files?.[0];
    if (!file) return;
    if (type === "image") setUploadingImage(true);
    else setUploadingSvga(true);
    const formData = new FormData();
    formData.append("file", file);
    const res =
      type === "image"
        ? await uploadRoomDecorationImage(formData)
        : await uploadRoomDecorationSvga(formData);
    if (res.success && res.url) {
      if (type === "image") {
        setImageUrl(res.url);
        setMediaKind("image");
      } else {
        setSvgaUrl(res.url);
        setMediaKind("svga");
      }
      setError("");
    } else {
      setError("Upload failed: " + (res.error || "Unknown error"));
    }
    if (type === "image") setUploadingImage(false);
    else setUploadingSvga(false);
    e.target.value = "";
  }
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError("");
    const trimmedName = name.trim();
    if (!trimmedName) {
      setError("Name is required");
      return;
    }
    if (mediaKind === "image" && !imageUrl.trim()) {
      setError("Upload or paste a background image");
      return;
    }
    if (mediaKind === "svga" && !svgaUrl.trim()) {
      setError("Upload or paste an SVGA file");
      return;
    }
    setLoading(true);
    try {
      const res = await upsertRoomDecoration({
        id: item?.id,
        name: trimmedName,
        image_url: mediaKind === "image" ? imageUrl.trim() : "",
        svga_url: mediaKind === "svga" ? svgaUrl.trim() : "",
        is_premium: isPremium,
        price: parseInt(price || "0", 10) || 0,
        is_active: isActive,
        sort_order: parseInt(sortOrder || "0", 10) || 0,
      });
      if (res?.success) {
        router.push("/settings/room-decorations");
        router.refresh();
        return;
      }
      setError(res?.error || "Save failed. Please try again.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Save failed. Please try again.");
    } finally {
      setLoading(false);
    }
  }
  async function handleDelete() {
    if (!item?.id) return;
    if (!confirm("Delete this room decoration?")) return;
    setDeleting(true);
    const res = await deleteRoomDecoration(item.id);
    if (res.success) {
      router.push("/settings/room-decorations");
      router.refresh();
    } else {
      alert("Error: " + res.error);
    }
    setDeleting(false);
  }
  const uploading = mediaKind === "image" ? uploadingImage : uploadingSvga;
  return (
    <form onSubmit={handleSubmit} noValidate className="grid grid-cols-1 lg:grid-cols-3 gap-12">
      {error && (
        <div className="lg:col-span-3 rounded-2xl border border-red-500/40 bg-red-500/10 px-6 py-4 text-sm text-red-200">
          {error}
        </div>
      )}
      <div className="lg:col-span-1 space-y-8">
        <div className="glass-card overflow-hidden p-0">
          <div className="aspect-[9/16] max-h-[420px] mx-auto bg-black/60 flex items-center justify-center border-b border-white/5 relative">
            {mediaKind === "image" && imageUrl ? (
              <CdnImg src={imageUrl} alt="Preview" className="w-full h-full object-cover" />
            ) : mediaKind === "svga" && svgaUrl ? (
              <div className="flex flex-col items-center gap-3 text-blue-300/80 p-6 text-center">
                <Sparkles size={48} />
                <p className="text-xs font-bold uppercase tracking-widest">SVGA ready</p>
                <p className="text-[10px] text-white/40 break-all">{svgaUrl.split("/").pop()}</p>
              </div>
            ) : (
              <Palette size={64} className="text-indigo-500/20" />
            )}
            {uploading && (
              <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
                <Loader2 size={32} className="animate-spin text-indigo-500" />
              </div>
            )}
          </div>

          <div className="p-8 space-y-6">
            <div className="space-y-3">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest">
                Background type
              </label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => setMediaKind("image")}
                  className={`flex items-center justify-center gap-2 py-3 rounded-xl border text-xs font-bold uppercase transition-all ${
                    mediaKind === "image"
                      ? "bg-indigo-500/20 border-indigo-500 text-indigo-300"
                      : "bg-white/5 border-white/10 text-white/50 hover:bg-white/10"
                  }`}
                >
                  <ImageIcon size={14} /> Image
                </button>
                <button
                  type="button"
                  onClick={() => setMediaKind("svga")}
                  className={`flex items-center justify-center gap-2 py-3 rounded-xl border text-xs font-bold uppercase transition-all ${
                    mediaKind === "svga"
                      ? "bg-blue-500/20 border-blue-500 text-blue-300"
                      : "bg-white/5 border-white/10 text-white/50 hover:bg-white/10"
                  }`}
                >
                  <Sparkles size={14} /> SVGA
                </button>
              </div>
              <p className="text-[10px] text-white/30 leading-relaxed">
                Choose one — image ya SVGA. Dono ek sath required nahi.
              </p>
            </div>

            {mediaKind === "image" ? (
              <div className="space-y-4">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest">
                  Background image (9:16 portrait)
                </label>
                <input
                  value={imageUrl}
                  onChange={(e) => setImageUrl(e.target.value)}
                  placeholder="https://..."
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-xs font-mono"
                />
                <button
                  type="button"
                  onClick={() => imageInputRef.current?.click()}
                  disabled={uploadingImage}
                  className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-white/5 border border-white/10 hover:bg-indigo-500/20 text-xs font-bold uppercase disabled:opacity-50"
                >
                  {uploadingImage ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Upload size={14} />
                  )}
                  Upload image
                </button>
                <input
                  ref={imageInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => handleFileUpload(e, "image")}
                />
              </div>
            ) : (
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest flex items-center gap-2">
                    <Sparkles size={10} /> SVGA background
                  </label>
                  {svgaUrl && <CheckCircle2 size={12} className="text-blue-500" />}
                </div>
                <input
                  value={svgaUrl}
                  onChange={(e) => setSvgaUrl(e.target.value)}
                  placeholder="https://.../animation.svga"
                  className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-xs font-mono"
                />
                <button
                  type="button"
                  onClick={() => svgaInputRef.current?.click()}
                  disabled={uploadingSvga}
                  className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-white/5 border border-white/10 hover:bg-blue-500/20 text-xs font-bold uppercase disabled:opacity-50"
                >
                  {uploadingSvga ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Upload size={14} />
                  )}
                  Upload SVGA file
                </button>
                <input
                  ref={svgaInputRef}
                  type="file"
                  accept=".svga"
                  className="hidden"
                  onChange={(e) => handleFileUpload(e, "svga")}
                />
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="lg:col-span-2 glass-card p-10 space-y-8">
        <div className="space-y-2">
          <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest">
            Name
          </label>
          <input
            name="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-2xl px-6 py-4 text-lg font-bold"
            placeholder="Neon Party"
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-2">
            <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest flex items-center gap-2">
              <Coins size={10} /> Price (coins)
            </label>
            <input
              name="price"
              type="number"
              min={0}
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              readOnly={!isPremium}
              className="w-full bg-black/40 border border-white/10 rounded-2xl px-6 py-4 font-mono read-only:opacity-40"
            />
          </div>
          <div className="space-y-2">
            <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest">
              Sort order
            </label>
            <input
              name="sort_order"
              type="number"
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
              className="w-full bg-black/40 border border-white/10 rounded-2xl px-6 py-4 font-mono"
            />
          </div>
        </div>

        <div className="flex flex-wrap gap-8">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={isPremium}
              onChange={(e) => setIsPremium(e.target.checked)}
              className="w-5 h-5 rounded"
            />
            <span className="text-sm font-bold">Premium (charge coins)</span>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              name="is_active"
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="w-5 h-5 rounded"
            />
            <span className="text-sm font-bold">Active (visible in app)</span>
          </label>
        </div>

        <div className="flex gap-4 pt-4">
          <button
            type="submit"
            disabled={loading || uploadingImage || uploadingSvga}
            className="flex-1 flex items-center justify-center gap-3 bg-indigo-500 text-black font-black uppercase tracking-widest py-5 rounded-2xl hover:scale-[1.02] transition-all disabled:opacity-50"
          >
            {loading ? <Loader2 className="animate-spin" /> : <Save size={20} />}
            Save decoration
          </button>
          {item?.id && (
            <button
              type="button"
              onClick={handleDelete}
              disabled={deleting}
              className="px-8 py-5 rounded-2xl border border-red-500/30 text-red-400 hover:bg-red-500/10 font-bold uppercase text-xs tracking-widest"
            >
              {deleting ? <Loader2 className="animate-spin" /> : <Trash2 size={18} />}
            </button>
          )}
        </div>
      </div>
    </form>
  );
}
