import { supabaseAdmin } from "@/lib/supabase";
import { Plus, ShoppingBag, Search, Layers } from "lucide-react";
import Link from "next/link";
import { ShopItemCard } from "@/components/ShopItemCard";
export default async function ShopPage({
  searchParams,
}: {
  searchParams: Promise<{
    category?: string;
    query?: string;
  }>;
}) {
  const { category, query } = await searchParams;
  const { data: categories } = await supabaseAdmin
    .from("shop_categories")
    .select("*")
    .order("display_order", { ascending: true });
  let itemsQuery = supabaseAdmin
    .from("shop_items")
    .select("*, shop_categories(name)")
    .order("created_at", { ascending: false });
  if (category) {
    itemsQuery = itemsQuery.eq("category_id", category);
  }
  if (query) {
    itemsQuery = itemsQuery.ilike("name", `%${query}%`);
  }
  const { data: items } = await itemsQuery;
  return (
    <div className="space-y-10 pb-32">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 className="text-6xl font-black bg-clip-text text-transparent bg-gradient-to-r from-amber-400 via-orange-500 to-yellow-500 tracking-tighter">
            Marketplace
          </h1>
          <p className="text-white/60 mt-2 font-medium">
            Manage virtual goods — click any item to send it to a user
          </p>
        </div>

        <div className="flex items-center gap-4 flex-wrap">
          <Link
            href="/shop/categories"
            className="flex items-center gap-3 bg-white/5 border border-white/10 px-8 py-4 rounded-2xl text-white font-black uppercase tracking-widest hover:bg-white/10 transition-all active:scale-95"
          >
            Categories
          </Link>
          <Link
            href={category ? `/shop/bulk?category=${category}` : "/shop/bulk"}
            className="flex items-center gap-3 bg-white/5 border border-emerald-500/30 px-8 py-4 rounded-2xl text-emerald-300 font-black uppercase tracking-widest hover:bg-emerald-500/10 transition-all active:scale-95"
          >
            <Layers size={20} /> Bulk Upload
          </Link>
          <Link
            href="/shop/new"
            className="flex items-center gap-3 bg-gradient-to-r from-amber-500 to-orange-600 px-8 py-4 rounded-2xl text-black font-black uppercase tracking-widest hover:scale-105 transition-all shadow-xl shadow-orange-500/20 active:scale-95"
          >
            <Plus size={20} /> New Item
          </Link>
        </div>
      </header>

      <div className="flex flex-col lg:flex-row gap-6 items-center">
        <div className="flex-1 flex items-center gap-2 overflow-x-auto pb-2 w-full lg:w-auto no-scrollbar">
          <Link
            href="/shop"
            className={`px-6 py-3 rounded-xl text-xs font-black uppercase tracking-widest whitespace-nowrap transition-all border ${
              !category
                ? "bg-amber-500 text-black border-transparent"
                : "bg-white/5 text-white/40 border-white/10 hover:bg-white/10"
            }`}
          >
            All Items
          </Link>
          {categories?.map((cat) => (
            <Link
              key={cat.id}
              href={`/shop?category=${cat.id}`}
              className={`px-6 py-3 rounded-xl text-xs font-black uppercase tracking-widest whitespace-nowrap transition-all border ${
                category === cat.id
                  ? "bg-amber-500 text-black border-transparent"
                  : "bg-white/5 text-white/40 border-white/10 hover:bg-white/10"
              }`}
            >
              {cat.name}
            </Link>
          ))}
        </div>

        <div className="relative w-full lg:w-80">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-white/20" size={18} />
          <input
            placeholder="Search items..."
            className="w-full bg-white/5 border border-white/10 rounded-2xl pl-12 pr-6 py-4 focus:outline-none focus:border-amber-500/50 transition-all text-sm font-medium"
          />
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {items?.map((item) => (
          <ShopItemCard
            key={item.id}
            id={item.id}
            name={item.name}
            imageUrl={item.image_url}
            svgaUrl={item.svga_url}
            categoryName={item.shop_categories?.name}
            priceCoins={item.price_coins}
            durationDays={item.duration_days}
            isActive={item.is_active !== false}
          />
        ))}
      </div>

      {items?.length === 0 && (
        <div className="py-32 text-center space-y-4">
          <div className="w-20 h-20 bg-white/5 rounded-full flex items-center justify-center mx-auto text-white/20">
            <ShoppingBag size={40} />
          </div>
          <p className="text-white/40 font-medium tracking-tight">
            No items found in this category.
          </p>
        </div>
      )}
    </div>
  );
}
