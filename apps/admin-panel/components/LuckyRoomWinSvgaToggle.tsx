"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  setLuckyRoomFanbiSvgaEnabled,
  setLuckyRoomMultiplierSvgaEnabled,
} from "@/app/settings/lucky-gifts/actions";
import { Loader2 } from "lucide-react";
function ToggleRow({
  title,
  description,
  enabled,
  pending,
  error,
  onToggle,
}: {
  title: string;
  description: string;
  enabled: boolean;
  pending: boolean;
  error: string | null;
  onToggle: () => void;
}) {
  return (
    <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-5 rounded-2xl border border-white/10 bg-black/20">
      <div className="space-y-1">
        <h3 className="text-sm font-bold text-amber-300">{title}</h3>
        <p className="text-xs text-white/40 max-w-xl">{description}</p>
        {error && <p className="text-xs text-red-400">{error}</p>}
      </div>
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={onToggle}
          disabled={pending}
          className={`relative inline-flex h-9 w-16 items-center rounded-full transition-colors ${enabled ? "bg-emerald-500" : "bg-white/15"} disabled:opacity-50`}
          aria-pressed={enabled}
        >
          {pending ? (
            <Loader2
              size={14}
              className="absolute left-1/2 -translate-x-1/2 animate-spin text-white"
            />
          ) : (
            <span
              className={`inline-block h-7 w-7 transform rounded-full bg-white shadow transition ${enabled ? "translate-x-8" : "translate-x-1"}`}
            />
          )}
        </button>
        <span className="text-xs font-mono text-white/50 min-w-[36px]">
          {enabled ? "ON" : "OFF"}
        </span>
      </div>
    </div>
  );
}
export function LuckyRoomWinSvgaToggle({
  initialFanbiEnabled,
  initialMultiplierEnabled,
}: {
  initialFanbiEnabled: boolean;
  initialMultiplierEnabled: boolean;
}) {
  const router = useRouter();
  const [fanbi, setFanbi] = useState(initialFanbiEnabled);
  const [multiplier, setMultiplier] = useState(initialMultiplierEnabled);
  const [fanbiPending, startFanbi] = useTransition();
  const [multPending, startMult] = useTransition();
  const [fanbiError, setFanbiError] = useState<string | null>(null);
  const [multError, setMultError] = useState<string | null>(null);
  function toggleFanbi() {
    const next = !fanbi;
    setFanbi(next);
    setFanbiError(null);
    startFanbi(async () => {
      const res = await setLuckyRoomFanbiSvgaEnabled(next);
      if (!res.success) {
        setFanbi(!next);
        setFanbiError(res.error ?? "Failed to save");
        return;
      }
      router.refresh();
    });
  }
  function toggleMultiplier() {
    const next = !multiplier;
    setMultiplier(next);
    setMultError(null);
    startMult(async () => {
      const res = await setLuckyRoomMultiplierSvgaEnabled(next);
      if (!res.success) {
        setMultiplier(!next);
        setMultError(res.error ?? "Failed to save");
        return;
      }
      router.refresh();
    });
  }
  return (
    <div className="glass-card p-6 space-y-4 border border-amber-500/20">
      <div>
        <h2 className="text-lg font-bold text-white">Room win animations</h2>
        <p className="text-xs text-white/40 mt-1">
          Fanbi and multiplier can be toggled separately. Below, each multiplier row still has its
          own on/off (same as before). Top global win patti is separate.
        </p>
      </div>
      <ToggleRow
        title="Fanbi animation"
        description="Beaver / fanbi SVGA in the middle of the room after a Lucky or Lucky Pro bonus."
        enabled={fanbi}
        pending={fanbiPending}
        error={fanbiError}
        onToggle={toggleFanbi}
      />
      <ToggleRow
        title="Multiplier animation (all)"
        description="Master switch for every xN multiplier SVGA. When OFF, no multiplier plays even if individual rows are enabled. When ON, only rows with is_enabled play."
        enabled={multiplier}
        pending={multPending}
        error={multError}
        onToggle={toggleMultiplier}
      />
    </div>
  );
}
