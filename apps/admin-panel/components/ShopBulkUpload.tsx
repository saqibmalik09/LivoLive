"use client";
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { bulkCreateShopItems, uploadFile, type BulkShopItemInput } from "@/app/shop/actions";
import { RankingAssetUrlPreview } from "@/components/RankingAssetUrlPreview";
import { isSvgaRankingAsset } from "@/lib/ranking-asset-media";
import { Loader2, Trash2, Upload, Layers } from "lucide-react";
type Category = {
  id: string;
  name: string;
};
type BulkRow = {
  id: string;
  fileName: string;
  name: string;
  kind: "image" | "svga";
  previewSrc: string;
  remoteUrl?: string;
  status: "pending" | "uploading" | "ready" | "error";
  error?: string;
};
function stemName(fileName: string) {
  return (
    fileName
      .replace(/\.[^.]+$/, "")
      .replace(/[_-]+/g, " ")
      .trim() || fileName
  );
}
export function ShopBulkUpload({
  categories,
  initialCategoryId,
}: {
  categories: Category[];
  initialCategoryId?: string;
}) {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const blobUrlsRef = useRef<string[]>([]);
  const [categoryId, setCategoryId] = useState(initialCategoryId || categories[0]?.id || "");
  const [priceCoins, setPriceCoins] = useState(0);
  const [durationDays, setDurationDays] = useState(7);
  const [isActive, setIsActive] = useState(true);
  const [isForSale, setIsForSale] = useState(true);
  const [isGift, setIsGift] = useState(false);
  const [isFullScreen, setIsFullScreen] = useState(false);
  const [rows, setRows] = useState<BulkRow[]>([]);
  const [saving, setSaving] = useState(false);
  const [progress, setProgress] = useState("");
  useEffect(() => {
    return () => {
      blobUrlsRef.current.forEach((url) => {
        if (url.startsWith("blob:")) URL.revokeObjectURL(url);
      });
    };
  }, []);
  const readyCount = useMemo(
    () => rows.filter((r) => r.status === "ready" && r.remoteUrl).length,
    [rows],
  );
  async function onPickFiles(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    if (!files.length) return;
    const nextRows: BulkRow[] = files.map((file) => {
      const isSvga = isSvgaRankingAsset(file.name, file.type);
      const previewSrc = URL.createObjectURL(file);
      blobUrlsRef.current.push(previewSrc);
      return {
        id: `${Date.now()}-${Math.random().toString(36).slice(2)}-${file.name}`,
        fileName: file.name,
        name: stemName(file.name),
        kind: isSvga ? "svga" : "image",
        previewSrc,
        status: "pending",
      };
    });
    setRows((prev) => [...prev, ...nextRows]);
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const rowId = nextRows[i].id;
      setRows((prev) => prev.map((r) => (r.id === rowId ? { ...r, status: "uploading" } : r)));
      setProgress(`Uploading ${i + 1}/${files.length}: ${file.name}`);
      const formData = new FormData();
      formData.append("file", file);
      const res = await uploadFile(formData);
      if (res.success && res.url) {
        setRows((prev) =>
          prev.map((r) => (r.id === rowId ? { ...r, status: "ready", remoteUrl: res.url } : r)),
        );
      } else {
        setRows((prev) =>
          prev.map((r) =>
            r.id === rowId
              ? {
                  ...r,
                  status: "error",
                  error: res.error ?? "Upload failed",
                }
              : r,
          ),
        );
      }
    }
    setProgress("");
    e.target.value = "";
  }
  function removeRow(id: string) {
    setRows((prev) => {
      const row = prev.find((r) => r.id === id);
      if (row?.previewSrc.startsWith("blob:")) {
        URL.revokeObjectURL(row.previewSrc);
        blobUrlsRef.current = blobUrlsRef.current.filter((u) => u !== row.previewSrc);
      }
      return prev.filter((r) => r.id !== id);
    });
  }
  async function handleCreate() {
    if (!categoryId) {
      alert("Select a category first");
      return;
    }
    const ready = rows.filter((r) => r.status === "ready" && r.remoteUrl);
    if (!ready.length) {
      alert("Upload at least one file first");
      return;
    }
    setSaving(true);
    const payload: BulkShopItemInput[] = ready.map((r) => ({
      name: r.name.trim() || stemName(r.fileName),
      category_id: categoryId,
      price_coins: priceCoins,
      duration_days: durationDays,
      image_url: r.kind === "image" ? r.remoteUrl : "",
      svga_url: r.kind === "svga" ? r.remoteUrl : "",
      is_active: isActive,
      is_for_sale: isForSale,
      is_gift: isGift,
      is_full_screen: isFullScreen,
      source_type: "shop",
    }));
    const res = await bulkCreateShopItems(payload);
    setSaving(false);
    if (!res.success) {
      alert(res.error ?? "Bulk create failed");
      return;
    }
    router.push(`/shop?category=${categoryId}`);
    router.refresh();
  }
  return (
    <div className="space-y-8">
      <div className="glass-card p-8 space-y-6">
        <div className="flex items-center gap-3">
          <Layers className="text-amber-400" />
          <div>
            <h2 className="text-xl font-black">Bulk upload into one category</h2>
            <p className="text-sm text-white/50">
              Pick many images and/or SVGA files. Each file becomes one shop item. SVGA previews
              play below so you can confirm what you selected.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <label className="space-y-2">
            <span className="text-[10px] font-bold uppercase text-white/40 tracking-widest">
              Category
            </span>
            <select
              value={categoryId}
              onChange={(e) => setCategoryId(e.target.value)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 font-semibold"
            >
              <option value="">Select…</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <label className="space-y-2">
            <span className="text-[10px] font-bold uppercase text-white/40 tracking-widest">
              Price (coins)
            </span>
            <input
              type="number"
              value={priceCoins}
              onChange={(e) => setPriceCoins(parseInt(e.target.value, 10) || 0)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 font-mono"
            />
          </label>
          <label className="space-y-2">
            <span className="text-[10px] font-bold uppercase text-white/40 tracking-widest">
              Duration (days)
            </span>
            <input
              type="number"
              value={durationDays}
              onChange={(e) => setDurationDays(parseInt(e.target.value, 10) || 7)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 font-mono"
            />
          </label>
          <div className="space-y-2">
            <span className="text-[10px] font-bold uppercase text-white/40 tracking-widest">
              Flags
            </span>
            <div className="flex flex-wrap gap-3 pt-2 text-sm">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={isActive}
                  onChange={(e) => setIsActive(e.target.checked)}
                />
                Active
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={isForSale}
                  onChange={(e) => setIsForSale(e.target.checked)}
                />
                For sale
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={isGift}
                  onChange={(e) => setIsGift(e.target.checked)}
                />
                Gift
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={isFullScreen}
                  onChange={(e) => setIsFullScreen(e.target.checked)}
                />
                Full screen
              </label>
            </div>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="px-5 py-3 rounded-xl bg-emerald-500/20 text-emerald-300 font-bold flex items-center gap-2 hover:bg-emerald-500/30"
          >
            <Upload size={18} />
            Add files (image / SVGA)
          </button>
          <input
            ref={fileInputRef}
            type="file"
            multiple
            accept="image/*,.svga,application/octet-stream"
            className="hidden"
            onChange={(e) => void onPickFiles(e)}
          />
          {progress && (
            <span className="text-sm text-amber-300 flex items-center gap-2">
              <Loader2 size={14} className="animate-spin" />
              {progress}
            </span>
          )}
          <span className="text-sm text-white/40">
            {readyCount}/{rows.length} ready
          </span>
        </div>
      </div>

      {rows.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {rows.map((row) => (
            <div key={row.id} className="glass-card p-4 space-y-3 border border-white/10">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
                    {row.kind === "svga" ? "SVGA" : "Image"} · {row.status}
                  </p>
                  <input
                    value={row.name}
                    onChange={(e) =>
                      setRows((prev) =>
                        prev.map((r) => (r.id === row.id ? { ...r, name: e.target.value } : r)),
                      )
                    }
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-sm font-semibold"
                  />
                  <p className="text-[10px] text-white/30 truncate mt-1">{row.fileName}</p>
                </div>
                <button
                  type="button"
                  onClick={() => removeRow(row.id)}
                  className="p-2 rounded-lg text-red-300 hover:bg-red-500/10"
                >
                  <Trash2 size={16} />
                </button>
              </div>

              {row.kind === "svga" ? (
                <RankingAssetUrlPreview
                  previewSrc={row.previewSrc}
                  url={row.remoteUrl}
                  savedUrl={row.remoteUrl}
                  mediaType="svga"
                />
              ) : (
                <img
                  src={row.previewSrc}
                  alt={row.name}
                  className="w-full max-h-40 object-contain rounded-xl bg-black/40"
                />
              )}

              {row.status === "uploading" && (
                <p className="text-xs text-amber-300 flex items-center gap-2">
                  <Loader2 size={12} className="animate-spin" /> Uploading…
                </p>
              )}
              {row.status === "error" && <p className="text-xs text-red-300">{row.error}</p>}
              {row.status === "ready" && <p className="text-xs text-emerald-400">Uploaded</p>}
            </div>
          ))}
        </div>
      )}

      <div className="flex gap-3">
        <button
          type="button"
          disabled={saving || readyCount === 0 || !categoryId}
          onClick={() => void handleCreate()}
          className="px-8 py-4 rounded-2xl bg-amber-500 text-black font-black disabled:opacity-50 flex items-center gap-2"
        >
          {saving ? <Loader2 size={18} className="animate-spin" /> : <Layers size={18} />}
          Create {readyCount} item{readyCount === 1 ? "" : "s"}
        </button>
        <button
          type="button"
          onClick={() => router.push("/shop")}
          className="px-6 py-4 rounded-2xl bg-white/5 border border-white/10 font-bold"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
