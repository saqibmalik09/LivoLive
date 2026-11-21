import { CdnImg } from "@/components/CdnImg";
import { supabaseAdmin } from "@/lib/supabase";
import { CountryFlag } from "@/components/CountryFlag";
import { Search, User, Coins, Diamond, ShieldAlert, ChevronRight, ChevronLeft } from "lucide-react";
import Link from "next/link";
const PAGE_SIZE = 100;
interface UsersPageProps {
  searchParams: Promise<{
    search?: string;
    page?: string;
  }>;
}
function buildUsersUrl(page: number, search?: string) {
  const params = new URLSearchParams();
  if (search?.trim()) params.set("search", search.trim());
  if (page > 1) params.set("page", String(page));
  const query = params.toString();
  return query ? `/users?${query}` : "/users";
}
function pageWindow(current: number, total: number, max = 7): number[] {
  if (total <= max) {
    return Array.from({ length: total }, (_, i) => i + 1);
  }
  const half = Math.floor(max / 2);
  let start = Math.max(1, current - half);
  let end = start + max - 1;
  if (end > total) {
    end = total;
    start = end - max + 1;
  }
  return Array.from({ length: end - start + 1 }, (_, i) => start + i);
}
export default async function UsersPage({ searchParams }: UsersPageProps) {
  const { search, page: pageParam } = await searchParams;
  const requestedPage = Math.max(1, parseInt(pageParam || "1", 10) || 1);
  let query = supabaseAdmin
    .from("users")
    .select(
      "id, username, coins, diamonds, is_banned, user_level, avatar_url, is_reseller, country_code, short_id",
      { count: "exact" },
    )
    .order("created_at", { ascending: false });
  if (search?.trim()) {
    const term = search.trim();
    const asNumber = parseInt(term, 10);
    if (!Number.isNaN(asNumber) && String(asNumber) === term) {
      query = query.eq("short_id", asNumber);
    } else {
      query = query.ilike("username", `%${term}%`);
    }
  }
  const from = (requestedPage - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;
  const { data: users, error, count } = await query.range(from, to);
  const totalUsers = count ?? 0;
  const totalPages = Math.max(1, Math.ceil(totalUsers / PAGE_SIZE));
  const currentPage = Math.min(requestedPage, totalPages);
  const showingFrom = totalUsers === 0 ? 0 : (currentPage - 1) * PAGE_SIZE + 1;
  const showingTo = Math.min(currentPage * PAGE_SIZE, totalUsers);
  const pages = pageWindow(currentPage, totalPages);
  return (
    <div className="space-y-8 pb-12">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-pink-400 tracking-tighter">
            User Management
          </h1>
          <p className="text-white/60 mt-2 font-medium">
            {totalUsers > 0
              ? `Showing ${showingFrom}–${showingTo} of ${totalUsers.toLocaleString()} users`
              : "Search and manage user accounts"}
          </p>
        </div>

        <form className="relative w-full md:w-96 group" action="/users" method="get">
          <Search
            className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30 group-focus-within:text-purple-400 transition-colors"
            size={20}
          />
          <input
            type="text"
            name="search"
            defaultValue={search}
            placeholder="Search username or UID..."
            className="w-full bg-black/40 border border-white/10 rounded-2xl py-4 pl-12 pr-4 text-white placeholder:text-white/20 focus:outline-none focus:border-purple-500/50 focus:ring-4 focus:ring-purple-500/10 transition-all"
          />
        </form>
      </header>

      {error && (
        <div className="rounded-2xl border border-red-500/30 bg-red-500/10 px-6 py-4 text-sm text-red-200">
          Failed to load users: {error.message}
        </div>
      )}

      <div className="glass-card overflow-hidden !p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-white/5 bg-white/5">
                <th className="px-6 py-5 text-[10px] font-bold uppercase tracking-[0.2em] text-white/40">
                  User
                </th>
                <th className="px-6 py-5 text-[10px] font-bold uppercase tracking-[0.2em] text-white/40">
                  UID
                </th>
                <th className="px-6 py-5 text-[10px] font-bold uppercase tracking-[0.2em] text-white/40">
                  Level
                </th>
                <th className="px-6 py-5 text-[10px] font-bold uppercase tracking-[0.2em] text-white/40 text-center">
                  Coins
                </th>
                <th className="px-6 py-5 text-[10px] font-bold uppercase tracking-[0.2em] text-white/40 text-center">
                  Diamonds
                </th>
                <th className="px-6 py-5 text-[10px] font-bold uppercase tracking-[0.2em] text-white/40 text-center">
                  Status
                </th>
                <th className="px-6 py-5"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {users?.map((user) => (
                <tr key={user.id} className="group hover:bg-white/[0.02] transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-purple-500/20 border border-white/10 flex items-center justify-center overflow-hidden">
                        {user.avatar_url ? (
                          <CdnImg
                            src={user.avatar_url}
                            alt={user.username}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <User size={20} className="text-purple-400" />
                        )}
                      </div>
                      <div className="flex items-center gap-2 min-w-0">
                        <CountryFlag code={user.country_code} size={24} />
                        <span className="font-bold tracking-tight truncate">{user.username}</span>
                        {user.is_reseller && (
                          <span className="px-2 py-0.5 rounded-full bg-orange-500/10 border border-orange-500/20 text-orange-400 text-[9px] font-black uppercase tracking-widest">
                            Reseller
                          </span>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="font-mono text-sm font-bold text-white/70">
                      {user.short_id ?? "—"}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <span className="px-3 py-1 rounded-full bg-purple-500/10 border border-purple-500/20 text-purple-400 text-[10px] font-black uppercase">
                      Lvl {user.user_level}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-center">
                    <div className="flex items-center justify-center gap-1.5 text-amber-400 font-black tracking-tighter">
                      <Coins size={14} />
                      {user.coins?.toLocaleString() || 0}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-center">
                    <div className="flex items-center justify-center gap-1.5 text-blue-400 font-black tracking-tighter">
                      <Diamond size={14} />
                      {user.diamonds?.toLocaleString() || 0}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-center">
                    {user.is_banned ? (
                      <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase text-red-400 bg-red-400/10 px-2 py-1 rounded-md border border-red-400/20">
                        <ShieldAlert size={12} /> Banned
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase text-emerald-400 bg-emerald-400/10 px-2 py-1 rounded-md border border-emerald-400/20">
                        Active
                      </span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-right">
                    <Link
                      href={`/users/${user.id}`}
                      className="inline-flex items-center justify-center w-10 h-10 rounded-xl bg-white/5 border border-white/10 text-white/40 group-hover:text-white group-hover:border-white/20 transition-all"
                    >
                      <ChevronRight size={20} />
                    </Link>
                  </td>
                </tr>
              ))}
              {(!users || users.length === 0) && (
                <tr>
                  <td
                    colSpan={7}
                    className="px-6 py-20 text-center text-white/20 italic font-medium"
                  >
                    No users found matching your search.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4 px-6 py-5 border-t border-white/5 bg-white/[0.02]">
            <p className="text-xs text-white/40 font-medium">
              Page {currentPage} of {totalPages} · {PAGE_SIZE} users per page
            </p>

            <div className="flex items-center gap-2 flex-wrap justify-center">
              {currentPage > 1 ? (
                <Link
                  href={buildUsersUrl(currentPage - 1, search)}
                  className="inline-flex items-center gap-1 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-bold uppercase tracking-wider hover:bg-purple-500/20 hover:border-purple-500/30 transition-all"
                >
                  <ChevronLeft size={16} /> Prev
                </Link>
              ) : (
                <span className="inline-flex items-center gap-1 px-4 py-2 rounded-xl bg-white/[0.02] border border-white/5 text-xs font-bold uppercase tracking-wider text-white/20 cursor-not-allowed">
                  <ChevronLeft size={16} /> Prev
                </span>
              )}

              {pages.map((p) => (
                <Link
                  key={p}
                  href={buildUsersUrl(p, search)}
                  className={`min-w-10 h-10 inline-flex items-center justify-center rounded-xl text-xs font-black border transition-all ${
                    p === currentPage
                      ? "bg-purple-500 text-black border-purple-500"
                      : "bg-white/5 border-white/10 text-white/60 hover:bg-purple-500/20 hover:border-purple-500/30"
                  }`}
                >
                  {p}
                </Link>
              ))}

              {currentPage < totalPages ? (
                <Link
                  href={buildUsersUrl(currentPage + 1, search)}
                  className="inline-flex items-center gap-1 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-bold uppercase tracking-wider hover:bg-purple-500/20 hover:border-purple-500/30 transition-all"
                >
                  Next <ChevronRight size={16} />
                </Link>
              ) : (
                <span className="inline-flex items-center gap-1 px-4 py-2 rounded-xl bg-white/[0.02] border border-white/5 text-xs font-bold uppercase tracking-wider text-white/20 cursor-not-allowed">
                  Next <ChevronRight size={16} />
                </span>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
