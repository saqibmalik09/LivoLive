import { supabaseAdmin } from "@/lib/supabase";
import { ShopBulkUpload } from "@/components/ShopBulkUpload";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
export default async function ShopBulkPage({
  searchParams,
}: {
  searchParams: Promise<{
    category?: string;
  }>;
}) {
  const { category } = await searchParams;
  const { data: categories } = await supabaseAdmin
    .from("shop_categories")
    .select("id, name")
    .order("display_order", { ascending: true });
  return (
    <div className="space-y-10 pb-32">
      <Link
        href={category ? `/shop?category=${category}` : "/shop"}
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Shop</span>
      </Link>

      <header>
        <h1 className="text-5xl font-black tracking-tighter">Bulk Upload</h1>
        <p className="text-white/60 mt-2 font-medium max-w-2xl">
          Upload many images or SVGA files into one shop category at once.
        </p>
      </header>

      <ShopBulkUpload categories={categories ?? []} initialCategoryId={category} />
    </div>
  );
}
