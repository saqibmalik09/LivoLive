import { redirect } from "next/navigation";
import { getMerchantActor } from "@/lib/merchant-session";
import { getOverview, getSellers } from "@/lib/merchant-data";
import { Shell, Empty } from "@/components/Shell";
import { RechargeClient } from "./RechargeClient";

export const dynamic = "force-dynamic";

export default async function RechargePage() {
  const actor = await getMerchantActor();
  if (!actor) redirect("/login");
  if (actor.mustChangePassword) redirect("/change-password");

  const [o, sellers] = await Promise.all([
    getOverview(actor.userId),
    getSellers(actor.userId),
  ]);
  if (!o) {
    return (
      <Shell username={actor.username}>
        <Empty>Your merchant account could not be loaded.</Empty>
      </Shell>
    );
  }

  return (
    <Shell
      username={actor.username}
      displayName={o.display_name}
      shortId={o.short_id}
      blocked={o.is_blocked}
      blockedReason={o.blocked_reason}
    >
      <RechargeClient
        balance={o.wallet_balance}
        creditLimit={o.credit_limit}
        commission={o.commission_percent}
        blocked={o.is_blocked}
        recent={sellers.slice(0, 6).map((s) => ({
          id: s.id,
          username: s.username,
          short_id: s.short_id,
          avatar_url: s.avatar_url,
          reseller_coins: s.reseller_coins,
        }))}
      />
    </Shell>
  );
}
