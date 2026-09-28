import { supabaseAdmin } from "@/lib/supabase";
import Link from "next/link";
import {
  ArrowLeft,
  Wallet,
  Banknote,
  Store,
  ScrollText,
  ArrowRightLeft,
  Coins,
} from "lucide-react";
import { WalletSettingsClient } from "./WalletSettingsClient";
export default async function WalletSettingsPage() {
  const [
    { data: cashConfigs },
    { data: salaryConfigs },
    { data: withdrawConfigs },
    { data: paymentSetting },
  ] = await Promise.all([
    supabaseAdmin
      .from("cash_exchange_configs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(1),
    supabaseAdmin
      .from("diamond_salary_configs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(1),
    supabaseAdmin
      .from("withdrawal_configs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(1),
    supabaseAdmin
      .from("system_settings")
      .select("value")
      .eq("key", "payment_methods")
      .maybeSingle(),
  ]);
  let paymentMethods: string[] = ["Bank", "JazzCash", "EasyPaisa", "USDT"];
  try {
    const raw = paymentSetting?.value;
    if (typeof raw === "string") paymentMethods = JSON.parse(raw);
    else if (Array.isArray(raw)) paymentMethods = raw.map(String);
  } catch {}
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Settings</span>
      </Link>

      <div>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <Wallet size={48} className="text-violet-400" />
          Wallet Control
        </h1>
        <p className="text-white/40 mt-2">
          Full control for rates, withdrawals, payment methods, merchants & records
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <QuickLink href="/withdrawals" icon={Banknote} label="Withdrawals" />
        <QuickLink href="/settings/wallet/merchants" icon={Store} label="Merchants" />
        <QuickLink href="/settings/wallet/records" icon={ScrollText} label="Records" />
        <QuickLink href="/settings/exchange" icon={ArrowRightLeft} label="Diamond↔Coin" />
        <QuickLink href="/recharge" icon={Coins} label="Recharge packs" />
      </div>

      <WalletSettingsClient
        cashConfig={cashConfigs?.[0] ?? null}
        salaryConfig={salaryConfigs?.[0] ?? null}
        withdrawConfig={withdrawConfigs?.[0] ?? null}
        paymentMethods={paymentMethods}
      />
    </div>
  );
}
function QuickLink({ href, icon: Icon, label }: { href: string; icon: any; label: string }) {
  return (
    <Link
      href={href}
      className="glass-card !p-4 flex items-center gap-3 hover:border-violet-500/40 transition-all"
    >
      <Icon size={18} className="text-violet-400" />
      <span className="text-xs font-black uppercase tracking-widest">{label}</span>
    </Link>
  );
}
