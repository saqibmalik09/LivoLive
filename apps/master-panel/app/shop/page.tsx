import { supabaseAdmin } from '@/lib/supabase';
import { ArrowLeft, ShoppingBag } from 'lucide-react';
import Link from 'next/link';
import { ShopGrantInline } from './ShopGrantInline';
import { ShopItemThumb } from './ShopItemThumb';

export default async function ShopPage({
  searchParams,
}: {
  searchParams: Promise<{ category?: string; query?: string }>;
}) {
  const { category, query } = await searchParams;

  const { data: categories } = await supabaseAdmin
    .from('shop_categories')
    .select('*')
    .order('display_order', { ascending: true });

  let itemsQuery = supabaseAdmin
    .from('shop_items')
    .select('id, name, image_url, svga_url, category_id, shop_categories(name)')
    .eq('is_active', true)
    .order('created_at', { ascending: false });

  if (category) {
    itemsQuery = itemsQuery.eq('category_id', category);
  }
  if (query) {
    itemsQuery = itemsQuery.ilike('name', `%${query}%`);
  }

  const { data: items } = await itemsQuery;

  return (
    <div className="space-y-10 pb-32">
      <header className="space-y-4">
        <Link
          href="/"
          className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
        >
          <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
          <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
        </Link>
        <div>
          <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-amber-400 via-orange-500 to-yellow-500 tracking-tighter">
            Shop Grants
          </h1>
          <p className="text-white/60 mt-2 font-medium">
            Grant-only — no create / edit / delete
          </p>
        </div>
      </header>

      <div className="flex flex-col lg:flex-row gap-6 items-center">
        <div className="flex-1 flex items-center gap-2 overflow-x-auto pb-2 w-full lg:w-auto">
          <Link
            href="/shop"
            className={`px-6 py-3 rounded-xl text-xs font-black uppercase tracking-widest whitespace-nowrap transition-all border ${
              !category
                ? 'bg-amber-500 text-black border-transparent'
                : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
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
                  ? 'bg-amber-500 text-black border-transparent'
                  : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
              }`}
            >
              {cat.name}
            </Link>
          ))}
        </div>

        <form action="/shop" method="get" className="relative w-full lg:w-80">
          {category && <input type="hidden" name="category" value={category} />}
          <input
            name="query"
            defaultValue={query}
            placeholder="Search items..."
            className="w-full bg-white/5 border border-white/10 rounded-2xl pl-4 pr-6 py-4 focus:outline-none focus:border-amber-500/50 transition-all text-sm font-medium"
          />
        </form>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {items?.map((item: any) => {
          const cat = Array.isArray(item.shop_categories)
            ? item.shop_categories[0]
            : item.shop_categories;
          return (
            <div key={item.id} className="glass-card !p-5 space-y-4">
              <div className="aspect-square rounded-2xl bg-black/40 border border-white/5 overflow-hidden flex items-center justify-center">
                <ShopItemThumb
                  imageUrl={item.image_url}
                  svgaUrl={item.svga_url}
                  name={item.name}
                />
              </div>
              <div>
                <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/70">
                  {cat?.name ?? 'Item'}
                </p>
                <h3 className="font-bold mt-1 truncate">{item.name}</h3>
                <p className="text-[10px] text-white/30 font-mono mt-1 truncate">{item.id}</p>
              </div>
              <ShopGrantInline itemId={item.id} itemName={item.name} />
            </div>
          );
        })}
      </div>

      {items?.length === 0 && (
        <div className="py-32 text-center space-y-4">
          <div className="w-20 h-20 bg-white/5 rounded-full flex items-center justify-center mx-auto text-white/20">
            <ShoppingBag size={40} />
          </div>
          <p className="text-white/40 font-medium tracking-tight">No active items found.</p>
        </div>
      )}
    </div>
  );
}
