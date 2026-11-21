"use client";
import { CdnImg } from "@/components/CdnImg";
import { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  deleteRoomMicEmoji,
  uploadRoomMicEmojiAsset,
  upsertRoomMicEmoji,
} from "@/app/settings/room-emojis/actions";
import { Crown, Loader2, Save, Smile, Trash2, Upload } from "lucide-react";
interface RoomEmojiFormProps {
  emoji?: {
    id: string;
    name: string;
    image_url: string;
    svga_url?: string | null;
    is_premium?: boolean;
    is_active?: boolean;
    sort_order?: number;
  };
}
export function RoomEmojiForm({ emoji }: RoomEmojiFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [imageUrl, setImageUrl] = useState(emoji?.image_url || "");
  const [svgaUrl, setSvgaUrl] = useState(emoji?.svga_url || "");
  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadingSvga, setUploadingSvga] = useState(false);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const svgaInputRef = useRef<HTMLInputElement>(null);
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>, kind: "image" | "svga") {
    const file = e.target.files?.[0];
    if (!file) return;
    if (kind === "image") setUploadingImage(true);
    else setUploadingSvga(true);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("kind", kind);
    const res = await uploadRoomMicEmojiAsset(formData);
    if (res.success && res.url) {
      if (kind === "image") setImageUrl(res.url);
      else setSvgaUrl(res.url);
    } else {
      alert(`Upload failed: ${res.error ?? "Unknown error"}`);
    }
    if (kind === "image") setUploadingImage(false);
    else setUploadingSvga(false);
    e.target.value = "";
  }
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const formData = new FormData(e.currentTarget);
    const res = await upsertRoomMicEmoji({
      id: emoji?.id,
      name: formData.get("name") as string,
      image_url: imageUrl,
      svga_url: svgaUrl || null,
      is_premium: formData.get("is_premium") === "on",
      is_active: formData.get("is_active") === "on",
      sort_order: parseInt(String(formData.get("sort_order") ?? "0"), 10) || 0,
    });
    if (res.success) {
      router.push("/settings/room-emojis");
      router.refresh();
    } else {
      alert(`Error: ${res.error ?? "Unknown error"}`);
    }
    setLoading(false);
  }
  async function handleDelete() {
    if (!emoji?.id) return;
    if (!confirm("Delete this mic emoji?")) return;
    setDeleting(true);
    const res = await deleteRoomMicEmoji(emoji.id);
    if (res.success) {
      router.push("/settings/room-emojis");
      router.refresh();
    } else {
      alert(`Error: ${res.error ?? "Unknown error"}`);
    }
    setDeleting(false);
  }
  return (
    <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-3 gap-12">
      <div className="lg:col-span-1 space-y-8">
        <div className="glass-card overflow-hidden p-0">
          <div className="aspect-square bg-black/60 flex items-center justify-center border-b border-white/5 relative">
            {imageUrl ? (
              <CdnImg src={imageUrl} alt="Preview" className="w-4/5 h-4/5 object-contain" />
            ) : (
              <Smile size={64} className="text-amber-500/20" />
            )}
            {(uploadingImage || uploadingSvga) && (
              <div className="absolute inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center">
                <Loader2 size={32} className="animate-spin text-amber-500" />
              </div>
            )}
          </div>
          <div className="p-4 space-y-2">
            <button
              type="button"
              onClick={() => imageInputRef.current?.click()}
              className="w-full py-3 rounded-xl bg-white/5 border border-white/10 text-sm font-bold flex items-center justify-center gap-2 hover:bg-white/10"
            >
              <Upload size={16} /> Upload image
            </button>
            <button
              type="button"
              onClick={() => svgaInputRef.current?.click()}
              className="w-full py-3 rounded-xl bg-white/5 border border-white/10 text-sm font-bold flex items-center justify-center gap-2 hover:bg-white/10"
            >
              <Upload size={16} /> Upload SVGA (optional)
            </button>
          </div>
        </div>
        <input
          ref={imageInputRef}
          type="file"
          accept="image/png,image/jpeg,image/webp,image/gif"
          className="hidden"
          onChange={(e) => handleUpload(e, "image")}
        />
        <input
          ref={svgaInputRef}
          type="file"
          accept=".svga,application/octet-stream"
          className="hidden"
          onChange={(e) => handleUpload(e, "svga")}
        />
      </div>

      <div className="lg:col-span-2 space-y-8">
        <div className="glass-card p-8 space-y-6">
          <div>
            <label className="text-xs font-black uppercase tracking-widest text-white/40">
              Name
            </label>
            <input
              name="name"
              defaultValue={emoji?.name ?? ""}
              required
              className="mt-2 w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50"
              placeholder="Laugh, Heart eyes, etc."
            />
          </div>

          <div>
            <label className="text-xs font-black uppercase tracking-widest text-white/40">
              Sort order
            </label>
            <input
              name="sort_order"
              type="number"
              defaultValue={emoji?.sort_order ?? 0}
              className="mt-2 w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50"
            />
          </div>

          <div>
            <label className="text-xs font-black uppercase tracking-widest text-white/40">
              Image URL
            </label>
            <input
              value={imageUrl}
              onChange={(e) => setImageUrl(e.target.value)}
              required
              className="mt-2 w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 text-sm"
            />
          </div>

          <div>
            <label className="text-xs font-black uppercase tracking-widest text-white/40">
              SVGA URL (optional)
            </label>
            <input
              value={svgaUrl}
              onChange={(e) => setSvgaUrl(e.target.value)}
              className="mt-2 w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 text-sm"
            />
          </div>

          <label className="flex items-center gap-3 cursor-pointer">
            <input
              name="is_active"
              type="checkbox"
              defaultChecked={emoji?.is_active ?? true}
              className="w-5 h-5 rounded"
            />
            <span className="font-bold">Active (visible in app)</span>
          </label>

          <label className="flex items-center gap-3 cursor-pointer">
            <input
              name="is_premium"
              type="checkbox"
              defaultChecked={emoji?.is_premium ?? false}
              className="w-5 h-5 rounded"
            />
            <span className="font-bold flex items-center gap-2">
              <Crown size={16} className="text-amber-400" /> Premium (VIP users only)
            </span>
          </label>
        </div>

        <div className="flex flex-wrap gap-4">
          <button
            type="submit"
            disabled={loading}
            className="flex items-center gap-2 bg-gradient-to-r from-amber-500 to-orange-500 text-black font-black px-8 py-4 rounded-2xl uppercase tracking-widest disabled:opacity-50"
          >
            {loading ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} />}
            Save
          </button>
          {emoji?.id && (
            <button
              type="button"
              onClick={handleDelete}
              disabled={deleting}
              className="flex items-center gap-2 bg-red-500/20 text-red-300 font-bold px-8 py-4 rounded-2xl border border-red-500/30 disabled:opacity-50"
            >
              {deleting ? <Loader2 size={18} className="animate-spin" /> : <Trash2 size={18} />}
              Delete
            </button>
          )}
        </div>
      </div>
    </form>
  );
}
