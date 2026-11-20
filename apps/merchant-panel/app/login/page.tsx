"use client";
import { useActionState } from "react";
import { Store, Loader2 } from "lucide-react";
import { loginAction } from "./actions";

export default function LoginPage() {
  const [state, action, pending] = useActionState(loginAction, null);

  return (
    <main className="min-h-screen flex items-center justify-center px-5">
      <div className="w-full max-w-sm glass-card !p-8 space-y-6">
        <div className="text-center space-y-3">
          <div className="inline-flex p-3 rounded-2xl bg-emerald-500/15 text-emerald-300">
            <Store size={26} />
          </div>
          <div>
            <h1 className="text-2xl font-black tracking-tight">Merchant Panel</h1>
            <p className="text-white/40 text-xs mt-1">
              Sign in with the username your admin gave you
            </p>
          </div>
        </div>

        <form action={action} className="space-y-4">
          <div>
            <label className="text-[9px] font-black uppercase tracking-widest text-white/40">
              Username
            </label>
            <input
              name="username"
              autoComplete="username"
              autoCapitalize="none"
              spellCheck={false}
              required
              className="mt-2 w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40"
            />
          </div>
          <div>
            <label className="text-[9px] font-black uppercase tracking-widest text-white/40">
              Password
            </label>
            <input
              name="password"
              type="password"
              autoComplete="current-password"
              required
              className="mt-2 w-full bg-white/5 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 ring-emerald-400/40"
            />
          </div>

          {state?.error ? (
            <p className="text-xs text-rose-300 font-bold">{state.error}</p>
          ) : null}

          <button
            type="submit"
            disabled={pending}
            className="w-full inline-flex items-center justify-center gap-2 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 transition-colors font-black text-xs uppercase tracking-widest py-3.5 rounded-xl disabled:opacity-50"
          >
            {pending ? <Loader2 size={14} className="animate-spin" /> : null}
            Sign in
          </button>
        </form>
      </div>
    </main>
  );
}
