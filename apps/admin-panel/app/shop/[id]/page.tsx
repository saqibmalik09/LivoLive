import { supabaseAdmin } from "@/lib/supabase";
import { ShopItemForm } from "@/components/ShopItemForm";
import { ArrowLeft, ShoppingBag } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
interface ShopItemEditPageProps {
  params: Promise<{
    id: string;
  }>;
}
export default async function ShopItemEditPage({ params }: ShopItemEditPageProps) {
  const { id } = await params;
  const { data: item, error } = await supabaseAdmin
    .from("shop_items")
    .select("*, shop_categories(*)")
    .eq("id", id)
    .single();
  if (error || !item) {
    notFound();
  }
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

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-500 shadow-2xl shadow-amber-500/10">
          <ShoppingBag size={40} />
        </div>
        <div>
          <span className="text-[10px] font-black uppercase tracking-[0.4em] text-amber-500/60 mb-1 block">
            Item Configuration
          </span>
          <h1 className="text-5xl font-black tracking-tighter uppercase italic leading-none">
            {item.name}
          </h1>
        </div>
      </header>

      <ShopItemForm item={item} categories={categories || []} />
    </div>
  );
}
