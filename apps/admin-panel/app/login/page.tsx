"use client";
import React, { useState, useTransition } from "react";
import { Lock, ShieldCheck, Loader2 } from "lucide-react";
import { adminLoginAction } from "./actions";
export default function LoginPage() {
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [pending, startTransition] = useTransition();
  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    startTransition(async () => {
      const res = await adminLoginAction(
        (() => {
          const fd = new FormData();
          fd.set("password", password);
          return fd;
        })(),
      );
      if (res && !res.success) {
        setError(res.error);
      }
    });
  };
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-premium p-6">
      <div className="glass-card w-full max-w-md space-y-8 p-12">
        <div className="text-center">
          <div className="inline-flex p-4 bg-purple-500/20 rounded-3xl mb-4">
            <ShieldCheck size={48} className="text-purple-400" />
          </div>
          <h1 className="text-3xl font-black tracking-tight text-white">SK Live Admin</h1>
          <p className="text-white/40 mt-2">Enter master password to access</p>
        </div>

        <form onSubmit={handleLogin} className="space-y-6">
          <div className="space-y-2">
            <label className="text-xs font-bold uppercase tracking-widest text-white/50 ml-4">
              Master Password
            </label>
            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30" size={18} />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full h-14 bg-white/5 border border-white/10 rounded-2xl pl-12 pr-4 text-white focus:border-purple-500 outline-none transition-all text-center tracking-[0.5em]"
                placeholder="••••••••"
                required
                autoFocus
                disabled={pending}
              />
            </div>
          </div>

          {error && (
            <p className="text-red-400 text-xs font-bold text-center uppercase tracking-wider bg-red-400/10 py-3 rounded-xl">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={pending}
            className="w-full h-14 bg-gradient-to-r from-purple-600 to-blue-600 rounded-2xl font-black text-white uppercase tracking-widest hover:scale-[1.02] active:scale-95 transition-all shadow-xl shadow-purple-900/20 disabled:opacity-60 inline-flex items-center justify-center gap-2"
          >
            {pending ? <Loader2 className="animate-spin" size={18} /> : null}
            Sign In
          </button>
        </form>
      </div>
    </div>
  );
}
