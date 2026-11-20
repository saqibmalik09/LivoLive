import { redirect } from "next/navigation";
import { getMerchantActor } from "@/lib/merchant-session";
import { ChangePasswordForm } from "./ChangePasswordForm";

export const dynamic = "force-dynamic";

export default async function ChangePasswordPage() {
  const actor = await getMerchantActor();
  if (!actor) redirect("/login");

  return (
    <main className="min-h-screen flex items-center justify-center px-5">
      <ChangePasswordForm
        username={actor.username}
        forced={actor.mustChangePassword}
      />
    </main>
  );
}
