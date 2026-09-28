import { supabaseAdmin } from "@/lib/supabase";
import RechargeConfigPage from "./RechargeConfig";
export default async function RechargePage() {
  const { data: packages } = await supabaseAdmin
    .from("recharge_packages")
    .select("*")
    .order("sort_order", { ascending: true })
    .order("beans_amount", { ascending: true });
  return (
    <div className="p-4">
      <RechargeConfigPage packages={packages || []} />
    </div>
  );
}
