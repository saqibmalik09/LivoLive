"use client";
import { CdnImg } from "@/components/CdnImg";
import { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  upsertCPNestItem,
  deleteCPNestItem,
  uploadCPNestImage,
  uploadCPNestSvga,
} from "@/app/cp-nest/actions";
import {
  Save,
  Trash2,
  Loader2,
  Image as ImageIcon,
  Upload,
  CheckCircle2,
  Coins,
  Heart,
  Sparkles,
} from "lucide-react";
const CATEGORIES = [
  { value: "ring", label: "Ring" },
  { value: "boutique", label: "Boutique" },
  { value: "card", label: "Card" },
  { value: "frame", label: "Frame" },
  { value: "other", label: "Other" },
];
type MediaKind = "image" | "svga";
interface CPNestItemFormProps {
  item?: {
    id: string;
    name: string;
    price: number;
    image_url?: string | null;
    svga_url?: string | null;
    category?: string | null;
  };
}
function inferMediaKind(item?: CPNestItemFormProps["item"]): MediaKind {
  if (item?.svga_url?.trim()) return "svga";
  return "image";
}
export function CPNestItemForm({ item }: CPNestItemFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [mediaKind, setMediaKind] = useState<MediaKind>(() => inferMediaKind(item));
  const [imageUrl, setImageUrl] = useState(item?.image_url || "");
  const [svgaUrl, setSvgaUrl] = useState(item?.svga_url || "");
  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadingSvga, setUploadingSvga] = useState(false);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const svgaInputRef = useRef<HTMLInputElement>(null);
  async function handleFileUpload(e: React.ChangeEvent<HTMLInputElement>, type: MediaKind) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (type === "image") setUploadingImage(true);
    else setUploadingSvga(true);
    const formData = new FormData();
    formData.append("file", file);
    const res =
      type === "image" ? await uploadCPNestImage(formData) : await uploadCPNestSvga(formData);
    if (res.success && res.url) {
      if (type === "image") {
        setImageUrl(res.url);
        setMediaKind("image");
      } else {
        setSvgaUrl(res.url);
        setMediaKind("svga");
      }
    } else {
      alert("Upload failed: " + res.error);
    }
    if (type === "image") setUploadingImage(false);
    else setUploadingSvga(false);
    e.target.value = "";
  }
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const formData = new FormData(e.currentTarget);
    const res = await upsertCPNestItem({
      id: item?.id,
      name: formData.get("name") as string,
      price: parseInt(formData.get("price") as string, 10),
      image_url: imageUrl || null,
      svga_url: svgaUrl || null,
      category: (formData.get("category") as string) || null,
    });
    if (res.success) {
      router.push("/cp-nest");
      router.refresh();
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  async function handleDelete() {
    if (!item?.id) return;
    if (!confirm("Delete this CP Nest gift? Proposals using it may fail if referenced.")) return;
    setDeleting(true);
    const res = await deleteCPNestItem(item.id);
    if (res.success) {
      router.push("/cp-nest");
      router.refresh();
    } else {
      alert("Error: " + res.error);
    }
    setDeleting(false);
  }
  const uploading = uploadingImage || uploadingSvga;
  return (
    <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-3 gap-12">
      <div className="lg:col-span-1 space-y-8">
        <div className="glass-card overflow-hidden p-0">
          <div className="aspect-square bg-black/60 flex items-center justify-center border-b border-white/5 relative group">
            {mediaKind === "svga" && svgaUrl ? (
              <div className="flex flex-col items-center gap-3 text-pink-300/80 p-6 text-center">
                <Sparkles size={48} />
                <p className="text-xs font-bold uppercase tracking-widest">SVGA ready</p>
                <p className="text-[10px] text-white/40 break-all">{svgaUrl.split("/").pop()}</p>
              </div>
            ) : imageUrl ? (
              <CdnImg src={imageUrl} alt="Preview" className="w-4/5 h-4/5 object-contain" />
            ) : (
              <Heart size={64} className="text-pink-500/20" />
            )}
            {uploading && (
              <div className="absolute inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center">
                <Loader2 size={32} className="animate-spin text-pink-500" />
              </div>
            )}
          </div>

          <div className="p-8 space-y-5">
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setMediaKind("image")}
                className={`flex-1 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest border transition-all ${
                  mediaKind === "image"
                    ? "bg-pink-500 text-black border-transparent"
                    : "bg-white/5 text-white/40 border-white/10"
                }`}
              >
                Image
              </button>
              <button
                type="button"
                onClick={() => setMediaKind("svga")}
                className={`flex-1 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest border transition-all ${
                  mediaKind === "svga"
                    ? "bg-pink-500 text-black border-transparent"
                    : "bg-white/5 text-white/40 border-white/10"
                }`}
              >
                SVGA
              </button>
            </div>

            {mediaKind === "image" ? (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
                    <ImageIcon size={10} /> Gift image
                  </label>
                  {imageUrl && <CheckCircle2 size={12} className="text-emerald-500" />}
                </div>
                <div className="flex gap-2">
                  <input
                    value={imageUrl}
                    onChange={(e) => setImageUrl(e.target.value)}
                    placeholder="https://..."
                    className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-pink-500/50 transition-all text-xs font-mono"
                  />
                  <button
                    type="button"
                    onClick={() => imageInputRef.current?.click()}
                    disabled={uploading}
                    className="p-3 bg-white/5 border border-white/10 rounded-xl hover:bg-white/10 transition-all text-white/60 hover:text-white"
                  >
                    {uploadingImage ? (
                      <Loader2 size={18} className="animate-spin" />
                    ) : (
                      <Upload size={18} />
                    )}
                  </button>
                  <input
                    type="file"
                    ref={imageInputRef}
                    className="hidden"
                    accept="image/*,.svga,application/octet-stream"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f?.name.toLowerCase().endsWith(".svga")) {
                        handleFileUpload(e, "svga");
                      } else {
                        handleFileUpload(e, "image");
                      }
                    }}
                  />
                </div>
              </div>
            ) : (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
                    <Sparkles size={10} /> Gift SVGA
                  </label>
                  {svgaUrl && <CheckCircle2 size={12} className="text-emerald-500" />}
                </div>
                <div className="flex gap-2">
                  <input
                    value={svgaUrl}
                    onChange={(e) => setSvgaUrl(e.target.value)}
                    placeholder="https://.../*.svga"
                    className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-pink-500/50 transition-all text-xs font-mono"
                  />
                  <button
                    type="button"
                    onClick={() => svgaInputRef.current?.click()}
                    disabled={uploading}
                    className="p-3 bg-white/5 border border-white/10 rounded-xl hover:bg-white/10 transition-all text-white/60 hover:text-white"
                  >
                    {uploadingSvga ? (
                      <Loader2 size={18} className="animate-spin" />
                    ) : (
                      <Upload size={18} />
                    )}
                  </button>
                  <input
                    type="file"
                    ref={svgaInputRef}
                    className="hidden"
                    accept=".svga,application/octet-stream"
                    onChange={(e) => handleFileUpload(e, "svga")}
                  />
                </div>
              </div>
            )}

            <p className="text-[10px] text-white/30">
              Upload button accepts images and <span className="text-pink-400/80">.svga</span>.
              Bucket: <span className="font-mono text-pink-400/80">cp_nest_assets</span>
            </p>
            {imageUrl && svgaUrl && (
              <p className="text-[10px] text-emerald-400/80">
                Both set — app will play SVGA on the gift card (image used as fallback thumb).
              </p>
            )}
          </div>
        </div>

        <div className="flex flex-col gap-4">
          <button
            type="submit"
            disabled={loading || uploading}
            className="w-full py-5 bg-pink-500 hover:bg-pink-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 shadow-xl shadow-pink-500/10 active:scale-95 disabled:opacity-50"
          >
            {loading ? <Loader2 size={24} className="animate-spin" /> : <Save size={24} />}
            {item ? "Save changes" : "Create gift"}
          </button>

          {item && (
            <button
              type="button"
              onClick={handleDelete}
              disabled={deleting}
              className="w-full py-5 bg-red-500/10 border border-red-500/20 hover:bg-red-500 text-red-500 hover:text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 active:scale-95 disabled:opacity-50"
            >
              {deleting ? <Loader2 size={24} className="animate-spin" /> : <Trash2 size={24} />}
              Delete gift
            </button>
          )}
        </div>
      </div>

      <div className="lg:col-span-2">
        <div className="glass-card space-y-8 p-10">
          <div className="space-y-2">
            <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
              Gift name
            </label>
            <input
              required
              name="name"
              defaultValue={item?.name}
              placeholder="e.g. Diamond Ring"
              className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-pink-500/50 transition-all font-bold text-xl"
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
                <Coins size={10} /> Price (coins)
              </label>
              <input
                required
                type="number"
                min={0}
                name="price"
                defaultValue={item?.price ?? 0}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-pink-500/50 transition-all font-mono text-2xl font-black"
              />
              <p className="text-[10px] text-white/30 px-1">
                App users pay this amount when sending a CP proposal.
              </p>
            </div>

            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                Category
              </label>
              <select
                name="category"
                defaultValue={item?.category || "ring"}
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-pink-500/50 transition-all font-bold text-lg appearance-none"
              >
                {CATEGORIES.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
              <p className="text-[10px] text-white/30 px-1">
                Used for fallback icon in the app if media is missing.
              </p>
            </div>
          </div>
        </div>
      </div>
    </form>
  );
}
