import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { ArrowLeft, ScrollText } from "lucide-react";
export default async function WalletRecordsPage({
  searchParams,
}: {
  searchParams: Promise<{
    currency?: string;
    type?: string;
  }>;
}) {
  const sp = await searchParams;
  const currency = sp.currency || "all";
  const type = sp.type || "all";
  let query = supabaseAdmin
    .from("transactions")
    .select(
      "id, user_id, amount, transaction_type, currency_type, description, created_at, users:user_id(username, short_id)",
    )
    .order("created_at", { ascending: false })
    .limit(150);
  if (currency !== "all") query = query.eq("currency_type", currency);
  if (type !== "all") query = query.eq("transaction_type", type);
  const { data: rows, error } = await query;
  if (error) console.error(error.message);
  const filters = [
    { key: "currency", label: "All currencies", value: "all" },
    { key: "currency", label: "Coin", value: "coin" },
    { key: "currency", label: "Diamond", value: "diamond" },
    { key: "currency", label: "Cash", value: "cash" },
  ];
  const typeFilters = [
    "all",
    "recharge",
    "transfer_in",
    "seller_package",
    "exchange",
    "withdrawal",
    "withdrawal_hold",
    "withdrawal_refund",
    "diamond_salary_exchange",
    "cash_exchange_self",
    "cash_exchange_other_out",
    "transfer_out",
  ];
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings/wallet"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Wallet Control</span>
      </Link>

      <div>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <ScrollText size={48} className="text-amber-400" />
          Wallet Records
        </h1>
        <p className="text-white/40 mt-2">Latest ledger entries across coins, diamonds, and cash</p>
      </div>

      <div className="flex flex-wrap gap-2">
        {filters.map((f) => {
          const active = currency === f.value;
          const href =
            f.value === "all"
              ? `/settings/wallet/records?type=${type}`
              : `/settings/wallet/records?currency=${f.value}&type=${type}`;
          return (
            <Link
              key={f.value}
              href={href}
              className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest ${active ? "bg-amber-500 text-black" : "bg-white/5 text-white/50"}`}
            >
              {f.label}
            </Link>
          );
        })}
      </div>

      <div className="flex flex-wrap gap-2">
        {typeFilters.map((t) => {
          const active = type === t;
          const href =
            currency === "all"
              ? `/settings/wallet/records?type=${t}`
              : `/settings/wallet/records?currency=${currency}&type=${t}`;
          return (
            <Link
              key={t}
              href={href}
              className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest ${active ? "bg-violet-500 text-black" : "bg-white/5 text-white/40"}`}
            >
              {t}
            </Link>
          );
        })}
      </div>

      <div className="space-y-2">
        {(rows || []).length === 0 ? (
          <div className="glass-card p-12 text-center text-white/40">No records</div>
        ) : (
          (rows || []).map((r: any) => (
            <div
              key={r.id}
              className="glass-card !p-4 flex flex-wrap items-start justify-between gap-3"
            >
              <div className="min-w-0">
                <p className="font-bold truncate">
                  {r.users?.username || "User"} · ID {r.users?.short_id ?? "—"}
                </p>
                <p className="text-xs text-white/50 mt-1">
                  {r.transaction_type} · {r.currency_type}
                </p>
                <p className="text-xs text-white/30 mt-1 line-clamp-2">{r.description || "—"}</p>
              </div>
              <div className="text-right">
                <p className="font-black text-lg">{Number(r.amount).toLocaleString()}</p>
                <p className="text-[11px] text-white/30">
                  {new Date(r.created_at).toLocaleString()}
                </p>
                <a
                  href={`/users/${r.user_id}`}
                  className="text-[10px] font-black uppercase tracking-widest text-violet-300"
                >
                  User
                </a>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
