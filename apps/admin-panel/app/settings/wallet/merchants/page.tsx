import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import { ArrowLeft, Store } from "lucide-react";
import { MerchantsClient } from "./MerchantsClient";
export default async function WalletMerchantsPage() {
  const { data: merchants, error } = await supabaseAdmin
    .from("users")
    .select(
      "id, username, short_id, avatar_url, country_code, created_at, reseller_coins, is_reseller",
    )
    .eq("is_reseller", true)
    .order("username", { ascending: true })
    .limit(300);
  if (error) console.error(error.message);
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
          <Store size={48} className="text-sky-400" />
          Coin Sellers
        </h1>
        <p className="text-white/40 mt-2">
          Users with the reseller flag — shown in the app's Coin Merchant list. Supplied by merchants; manage the merchant tier under Settings → Merchants.
        </p>
      </div>

      <MerchantsClient merchants={(merchants as any[]) || []} />
    </div>
  );
}
