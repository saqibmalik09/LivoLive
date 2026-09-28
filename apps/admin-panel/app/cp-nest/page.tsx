import { supabaseAdmin } from "@/lib/supabase";
import { Plus, Heart, Search } from "lucide-react";
import Link from "next/link";
export default async function CPNestPage({
  searchParams,
}: {
  searchParams: Promise<{
    query?: string;
    category?: string;
  }>;
}) {
  const { query, category } = await searchParams;
  let itemsQuery = supabaseAdmin
    .from("cp_nest_items")
    .select("*")
    .order("price", { ascending: true });
  if (query) {
    itemsQuery = itemsQuery.ilike("name", `%${query}%`);
  }
  if (category) {
    itemsQuery = itemsQuery.eq("category", category);
  }
  const { data: items } = await itemsQuery;
  const categories = ["ring", "boutique", "card", "frame", "other"];
  return (
    <div className="space-y-10 pb-32">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 className="text-6xl font-black bg-clip-text text-transparent bg-gradient-to-r from-pink-400 via-rose-500 to-fuchsia-500 tracking-tighter">
            CP Nest
          </h1>
          <p className="text-white/60 mt-2 font-medium">
            Manage proposal gifts — name, price, image / SVGA (bucket{" "}
            <span className="font-mono text-pink-400/70">cp_nest_assets</span>)
          </p>
        </div>

        <Link
          href="/cp-nest/new"
          className="flex items-center gap-3 bg-gradient-to-r from-pink-500 to-rose-600 px-8 py-4 rounded-2xl text-black font-black uppercase tracking-widest hover:scale-105 transition-all shadow-xl shadow-pink-500/20 active:scale-95"
        >
          <Plus size={20} /> New gift
        </Link>
      </header>

      <div className="flex flex-col lg:flex-row gap-6 items-center">
        <div className="flex-1 flex items-center gap-2 overflow-x-auto pb-2 w-full lg:w-auto no-scrollbar">
          <Link
            href="/cp-nest"
            className={`px-6 py-3 rounded-xl text-xs font-black uppercase tracking-widest whitespace-nowrap transition-all border ${!category ? "bg-pink-500 text-black border-transparent" : "bg-white/5 text-white/40 border-white/10 hover:bg-white/10"}`}
          >
            All
          </Link>
          {categories.map((cat) => (
            <Link
              key={cat}
              href={`/cp-nest?category=${cat}`}
              className={`px-6 py-3 rounded-xl text-xs font-black uppercase tracking-widest whitespace-nowrap transition-all border ${category === cat ? "bg-pink-500 text-black border-transparent" : "bg-white/5 text-white/40 border-white/10 hover:bg-white/10"}`}
            >
              {cat}
            </Link>
          ))}
        </div>

        <form className="relative w-full lg:w-80" action="/cp-nest" method="get">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-white/20" size={18} />
          <input
            name="query"
            defaultValue={query}
            placeholder="Search gifts..."
            className="w-full bg-white/5 border border-white/10 rounded-2xl pl-12 pr-6 py-4 focus:outline-none focus:border-pink-500/50 transition-all text-sm font-medium"
          />
          {category && <input type="hidden" name="category" value={category} />}
        </form>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {items?.map((item) => (
          <Link
            key={item.id}
            href={`/cp-nest/${item.id}`}
            className="glass-card group hover:border-pink-500/30 transition-all p-4 overflow-hidden relative"
          >
            <div className="aspect-square rounded-2xl bg-black/40 border border-white/5 overflow-hidden flex items-center justify-center relative mb-6">
              {item.image_url ? (
                <img
                  src={item.image_url}
                  alt={item.name}
                  className="w-4/5 h-4/5 object-contain group-hover:scale-110 transition-transform duration-500"
                />
              ) : item.svga_url ? (
                <div className="flex flex-col items-center gap-2 text-pink-300/70">
                  <span className="text-[10px] font-black uppercase tracking-widest">SVGA</span>
                  <span className="text-[9px] text-white/30 px-3 text-center break-all">
                    {String(item.svga_url).split("/").pop()}
                  </span>
                </div>
              ) : (
                <Heart className="text-pink-500/20" size={48} />
              )}
              {item.svga_url && (
                <div className="absolute top-3 right-3 bg-fuchsia-500/25 border border-fuchsia-400/40 text-fuchsia-200 px-2 py-1 rounded text-[8px] font-black uppercase tracking-widest">
                  SVGA
                </div>
              )}
              {item.category && (
                <div className="absolute bottom-3 left-3 bg-pink-500/20 border border-pink-500/30 text-pink-300 px-2 py-1 rounded text-[8px] font-black uppercase tracking-widest">
                  {item.category}
                </div>
              )}
            </div>

            <h3 className="font-black text-xl tracking-tight text-white/90 leading-none mb-2">
              {item.name}
            </h3>
            <div className="flex items-baseline gap-1">
              <span className="text-2xl font-black text-white">
                {Number(item.price).toLocaleString()}
              </span>
              <span className="text-[10px] font-bold text-white/30 uppercase tracking-widest">
                Coins
              </span>
            </div>
          </Link>
        ))}
      </div>

      {items?.length === 0 && (
        <div className="py-32 text-center space-y-4">
          <div className="w-20 h-20 bg-white/5 rounded-full flex items-center justify-center mx-auto text-pink-500/30">
            <Heart size={40} />
          </div>
          <p className="text-white/40 font-medium tracking-tight">
            No CP Nest gifts yet. Create one to show in the app.
          </p>
          <Link
            href="/cp-nest/new"
            className="inline-block text-pink-400 font-bold text-sm hover:underline"
          >
            Add first gift →
          </Link>
        </div>
      )}
    </div>
  );
}
