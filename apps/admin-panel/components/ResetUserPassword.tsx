"use client";
import { useState } from "react";
import { KeyRound, Loader2, Copy, Check, RefreshCw } from "lucide-react";
import { resetUserPassword } from "@/app/users/actions";
function generatePassword(length = 12): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => chars[b % chars.length]).join("");
}
interface ResetUserPasswordProps {
  userId: string;
  userEmail: string | null;
}
export function ResetUserPassword({ userId, userEmail }: ResetUserPasswordProps) {
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [lastSetPassword, setLastSetPassword] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const fillGenerated = () => {
    setPassword(generatePassword());
    setLastSetPassword(null);
    setCopied(false);
  };
  const handleReset = async () => {
    const next = password.trim() || generatePassword();
    if (next.length < 6) {
      alert("Password must be at least 6 characters");
      return;
    }
    if (
      !confirm(
        `Reset login password for this user?\n\nThey will need this new password to sign in with Email/Password.\n${userEmail ? `Email: ${userEmail}` : "Note: user has no email on file."}`,
      )
    ) {
      return;
    }
    setLoading(true);
    setCopied(false);
    const res = await resetUserPassword(userId, next);
    setLoading(false);
    if (!res.success) {
      alert(`Error: ${res.error}`);
      return;
    }
    setPassword(next);
    setLastSetPassword(next);
  };
  const copyPassword = async () => {
    if (!lastSetPassword) return;
    try {
      await navigator.clipboard.writeText(lastSetPassword);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      alert(`Copy failed. Password: ${lastSetPassword}`);
    }
  };
  return (
    <div className="md:col-span-2 mt-2 rounded-2xl border border-amber-500/20 bg-amber-500/5 p-5 space-y-4">
      <div className="flex items-center gap-2 text-amber-300">
        <KeyRound size={18} />
        <h4 className="text-[11px] font-black uppercase tracking-widest">Reset Login Password</h4>
      </div>
      <p className="text-[11px] text-white/40 leading-relaxed">
        Sets a new Email/Password for this account (Supabase Auth). Copy it and share with the user.
        Social-only accounts (Google/Facebook) can still use this password after reset if email
        login is enabled.
      </p>

      <div className="flex flex-col sm:flex-row gap-3">
        <input
          type="text"
          value={password}
          onChange={(e) => {
            setPassword(e.target.value);
            setLastSetPassword(null);
            setCopied(false);
          }}
          placeholder="New password (or generate)"
          className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-mono text-white placeholder:text-white/25 focus:outline-none focus:border-amber-400/40"
          autoComplete="off"
          spellCheck={false}
        />
        <button
          type="button"
          onClick={fillGenerated}
          disabled={loading}
          className="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl border border-white/10 bg-white/5 text-[11px] font-black uppercase tracking-wider text-white/70 hover:bg-white/10 disabled:opacity-50"
        >
          <RefreshCw size={14} />
          Generate
        </button>
        <button
          type="button"
          onClick={handleReset}
          disabled={loading}
          className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-amber-500/90 hover:bg-amber-400 text-black text-[11px] font-black uppercase tracking-wider disabled:opacity-50"
        >
          {loading ? <Loader2 size={14} className="animate-spin" /> : <KeyRound size={14} />}
          Set Password
        </button>
      </div>

      {lastSetPassword && (
        <div className="flex flex-col sm:flex-row sm:items-center gap-3 rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-4 py-3">
          <div className="flex-1 min-w-0">
            <p className="text-[9px] font-black uppercase tracking-widest text-emerald-400/80 mb-1">
              New password (copy & send to user)
            </p>
            <p className="font-mono text-sm text-emerald-200 break-all select-all">
              {lastSetPassword}
            </p>
          </div>
          <button
            type="button"
            onClick={copyPassword}
            className="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-emerald-500/20 border border-emerald-400/30 text-emerald-200 text-[11px] font-black uppercase tracking-wider hover:bg-emerald-500/30"
          >
            {copied ? <Check size={14} /> : <Copy size={14} />}
            {copied ? "Copied" : "Copy"}
          </button>
        </div>
      )}
    </div>
  );
}
