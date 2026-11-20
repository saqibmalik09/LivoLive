"use client";
import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { KeyRound, Loader2 } from "lucide-react";
import { changePasswordAction } from "@/app/login/actions";

export function ChangePasswordForm({
  username,
  forced,
}: {
  username: string;
  forced: boolean;
}) {
  const router = useRouter();
  const [state, action, pending] = useActionState(changePasswordAction, null);

  if (state?.ok) {
    // Straight on to the panel once the forced change is done.
    setTimeout(() => router.replace("/"), 600);
  }

  return (
    <div className="w-full max-w-sm glass-card !p-8 space-y-6">
      <div className="text-center space-y-3">
        <div className="inline-flex p-3 rounded-2xl bg-emerald-500/15 text-emerald-300">
          <KeyRound size={24} />
        </div>
        <div>
          <h1 className="text-xl font-black tracking-tight">
            {forced ? "Set your password" : "Change password"}
          </h1>
          <p className="text-white/40 text-xs mt-1">
            {forced
              ? `Choose your own password before using the panel, @${username}.`
              : `Signed in as @${username}`}
          </p>
        </div>
      </div>

      <form action={action} className="space-y-4">
        <Field name="current" label="Current password" />
        <Field name="next" label="New password" />
        <Field name="confirm" label="Confirm new password" />

        {state?.error ? (
          <p className="text-xs text-rose-300 font-bold">{state.error}</p>
        ) : null}
        {state?.ok ? (
          <p className="text-xs text-emerald-300 font-bold">
            {state.ok} — taking you to the panel…
          </p>
        ) : null}

        <button
          type="submit"
          disabled={pending}
          className="w-full inline-flex items-center justify-center gap-2 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 transition-colors font-black text-xs uppercase tracking-widest py-3.5 rounded-xl disabled:opacity-50"
        >
          {pending ? <Loader2 size={14} className="animate-spin" /> : null}
          Save password
        </button>
      </form>
    </div>
  );
}

function Field({ name, label }: { name: string; label: string }) {
  return (
    <div>
      <label className="text-[9px] font-black uppercase tracking-widest text-white/40">
        {label}
      </label>
      <input
        name={name}
        type="password"
        autoComplete="new-password"
        required
        className="mt-2 w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40"
      />
    </div>
  );
}
