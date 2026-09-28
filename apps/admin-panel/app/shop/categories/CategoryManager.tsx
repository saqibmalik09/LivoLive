"use client";
import { useState, useRef } from "react";
import { upsertCategory, deleteCategory } from "./actions";
import { uploadFile } from "../actions";
import {
  Plus,
  Trash2,
  Edit2,
  Save,
  X,
  Loader2,
  GripVertical,
  Image as ImageIcon,
  Upload,
} from "lucide-react";
import { useRouter } from "next/navigation";
export function CategoryManager({ initialCategories }: { initialCategories: any[] }) {
  const router = useRouter();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [loading, setLoading] = useState<string | null>(null);
  const [newCategory, setNewCategory] = useState(false);
  async function handleSave(
    id: string | null,
    name: string,
    iconUrl: string,
    displayOrder: number,
  ) {
    setLoading(id || "new");
    const res = await upsertCategory({ id, name, icon_url: iconUrl, display_order: displayOrder });
    if (res.success) {
      setEditingId(null);
      setNewCategory(false);
      router.refresh();
    } else {
      alert(res.error);
    }
    setLoading(null);
  }
  async function handleDelete(id: string) {
    if (!confirm("Are you sure?")) return;
    setLoading(id);
    const res = await deleteCategory(id);
    if (res.success) {
      router.refresh();
    } else {
      alert(res.error);
    }
    setLoading(null);
  }
  return (
    <div className="space-y-6">
      <div className="grid gap-4">
        {initialCategories.map((cat) => (
          <div
            key={cat.id}
            className="glass-card p-4 flex items-center gap-6 group hover:border-blue-500/30 transition-all"
          >
            <div className="text-white/10 cursor-grab active:cursor-grabbing">
              <GripVertical size={20} />
            </div>

            <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center overflow-hidden border border-white/5">
              {cat.icon_url ? (
                <img src={cat.icon_url} alt="" className="w-8 h-8 object-contain" />
              ) : (
                <ImageIcon size={20} className="text-white/10" />
              )}
            </div>

            {editingId === cat.id ? (
              <EditRow
                cat={cat}
                onSave={(name, icon, order) => handleSave(cat.id, name, icon, order)}
                onCancel={() => setEditingId(null)}
                loading={loading === cat.id}
              />
            ) : (
              <>
                <div className="flex-1">
                  <h3 className="font-bold text-lg">{cat.name}</h3>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/20">
                    Order: {cat.display_order}
                  </p>
                </div>

                <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    onClick={() => setEditingId(cat.id)}
                    className="p-3 hover:bg-white/5 rounded-xl text-white/40 hover:text-white transition-all"
                  >
                    <Edit2 size={18} />
                  </button>
                  <button
                    onClick={() => handleDelete(cat.id)}
                    className="p-3 hover:bg-red-500/10 rounded-xl text-white/40 hover:text-red-500 transition-all"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              </>
            )}
          </div>
        ))}

        {newCategory ? (
          <div className="glass-card p-4 flex items-center gap-6 border-blue-500/50 bg-blue-500/5">
            <div className="w-12 h-12 rounded-xl bg-blue-500/20 flex items-center justify-center border border-blue-500/20">
              <Plus size={20} className="text-blue-400" />
            </div>
            <EditRow
              onSave={(name, icon, order) => handleSave(null, name, icon, order)}
              onCancel={() => setNewCategory(false)}
              loading={loading === "new"}
            />
          </div>
        ) : (
          <button
            onClick={() => setNewCategory(true)}
            className="w-full py-6 border-2 border-dashed border-white/5 rounded-3xl text-white/20 hover:text-blue-400 hover:border-blue-500/30 hover:bg-blue-500/5 transition-all flex items-center justify-center gap-3 font-black uppercase tracking-widest text-xs"
          >
            <Plus size={18} /> Add New Category
          </button>
        )}
      </div>
    </div>
  );
}
function EditRow({
  cat,
  onSave,
  onCancel,
  loading,
}: {
  cat?: any;
  onSave: (name: string, icon: string, order: number) => void;
  onCancel: () => void;
  loading: boolean;
}) {
  const [name, setName] = useState(cat?.name || "");
  const [icon, setIcon] = useState(cat?.icon_url || "");
  const [order, setOrder] = useState(cat?.display_order || 0);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const formData = new FormData();
    formData.append("file", file);
    const res = await uploadFile(formData);
    if (res.success && res.url) {
      setIcon(res.url);
    } else {
      alert("Upload failed");
    }
    setUploading(false);
  }
  return (
    <div className="flex-1 flex flex-col md:flex-row items-center gap-4">
      <input
        autoFocus
        placeholder="Category Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-2 focus:outline-none focus:border-blue-500/50"
      />
      <div className="flex-1 flex gap-2">
        <input
          placeholder="Icon URL"
          value={icon}
          onChange={(e) => setIcon(e.target.value)}
          className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-2 focus:outline-none focus:border-blue-500/50 text-xs font-mono"
        />
        <button
          onClick={() => fileInputRef.current?.click()}
          disabled={uploading}
          className="p-2 bg-white/5 border border-white/10 rounded-xl hover:bg-white/10 text-white/40 hover:text-white"
        >
          {uploading ? <Loader2 size={14} className="animate-spin" /> : <Upload size={14} />}
        </button>
        <input type="file" ref={fileInputRef} className="hidden" onChange={handleUpload} />
      </div>
      <input
        type="number"
        placeholder="Order"
        value={order}
        onChange={(e) => setOrder(parseInt(e.target.value))}
        className="w-20 bg-black/40 border border-white/10 rounded-xl px-4 py-2 focus:outline-none focus:border-blue-500/50"
      />
      <div className="flex items-center gap-2">
        <button
          disabled={loading || !name || uploading}
          onClick={() => onSave(name, icon, order)}
          className="p-3 bg-blue-500 text-black rounded-xl hover:scale-105 transition-all disabled:opacity-50"
        >
          {loading ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} />}
        </button>
        <button
          onClick={onCancel}
          className="p-3 bg-white/5 text-white/40 rounded-xl hover:text-white transition-all"
        >
          <X size={18} />
        </button>
      </div>
    </div>
  );
}
