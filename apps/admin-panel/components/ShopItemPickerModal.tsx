"use client";
import { CdnImg } from "@/components/CdnImg";
import { useEffect, useState } from "react";
import { Loader2, Search, X } from "lucide-react";
import { searchShopItemsForReward } from "@/lib/actions/shop-picker";
import { publicMediaUrl, storageThumbUrl } from "@/lib/media-url";
export type ShopPickerItem = {
  id: string;
  name: string;
  image_url: string | null;
};
interface ShopItemPickerModalProps {
  open: boolean;
  featureKey: string;
  title: string;
  onClose: () => void;
  onSelect: (item: ShopPickerItem) => void;
}
export function ShopItemPickerModal({
  open,
  featureKey,
  title,
  onClose,
  onSelect,
}: ShopItemPickerModalProps) {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<ShopPickerItem[]>([]);
  const [loading, setLoading] = useState(false);
  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      try {
        const data = await searchShopItemsForReward(featureKey, query);
        if (!cancelled) {
          setItems(
            data.map((item) => ({
              id: item.id,
              name: item.name,
              image_url: item.image_url,
            })),
          );
        }
      } catch {
        if (!cancelled) setItems([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    const timer = setTimeout(load, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [open, featureKey, query]);
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="glass-card w-full max-w-2xl max-h-[80vh] overflow-hidden border border-white/10 shadow-2xl">
        <div className="flex items-center justify-between border-b border-white/10 px-6 py-4">
          <div>
            <h3 className="text-lg font-bold text-white">{title}</h3>
            <p className="text-xs text-white/40">Select from existing shop assets</p>
          </div>
          <button
            onClick={onClose}
            className="rounded-lg p-2 text-white/40 hover:bg-white/10 hover:text-white"
          >
            <X size={18} />
          </button>
        </div>

        <div className="border-b border-white/10 px-6 py-4">
          <div className="relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-white/20" size={18} />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search shop items..."
              className="w-full rounded-2xl border border-white/10 bg-white/5 py-3 pl-12 pr-4 text-sm text-white focus:border-amber-500/50 focus:outline-none"
            />
          </div>
        </div>

        <div className="max-h-[50vh] overflow-y-auto p-4">
          {loading ? (
            <div className="flex items-center justify-center py-16 text-white/40">
              <Loader2 className="animate-spin" size={24} />
            </div>
          ) : items.length === 0 ? (
            <div className="py-16 text-center text-sm text-white/30">
              No matching shop items found
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              {items.map((item) => (
                <button
                  key={item.id}
                  onClick={() => {
                    onSelect(item);
                    onClose();
                  }}
                  className="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 p-3 text-left transition-colors hover:border-amber-500/40 hover:bg-white/10"
                >
                  {item.image_url ? (
                    <CdnImg
                      src={storageThumbUrl(item.image_url, 96)}
                      alt={item.name}
                      loading="lazy"
                      referrerPolicy="no-referrer"
                      onError={(e) => {
                        const full = publicMediaUrl(item.image_url);
                        if (full && e.currentTarget.src !== full) {
                          e.currentTarget.src = full;
                        }
                      }}
                      className="h-12 w-12 rounded-lg object-contain bg-black/20"
                    />
                  ) : (
                    <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-white/5 text-white/20">
                      ?
                    </div>
                  )}
                  <span className="text-sm font-medium text-white/80">{item.name}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
