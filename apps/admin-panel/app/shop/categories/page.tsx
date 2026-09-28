import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft, Plus, FolderPlus, Trash2, Edit2, GripVertical } from "lucide-react";
import Link from "next/link";
import { CategoryManager } from "./CategoryManager";
export default async function CategoriesPage() {
  const { data: categories } = await supabaseAdmin
    .from("shop_categories")
    .select("*")
    .order("display_order", { ascending: true });
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/shop"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Marketplace</span>
      </Link>

      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <span className="text-[10px] font-black uppercase tracking-[0.4em] text-blue-500 mb-1 block">
            Taxonomy Control
          </span>
          <h1 className="text-6xl font-black bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-indigo-500 tracking-tighter italic">
            Categories
          </h1>
          <p className="text-white/60 mt-2 font-medium">
            Manage how items are grouped in the shop and gift sheets
          </p>
        </div>
      </header>

      <div className="max-w-4xl">
        <CategoryManager initialCategories={categories || []} />
      </div>
    </div>
  );
}
