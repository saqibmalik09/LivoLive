"use client";
import { useState } from "react";
import {
  deleteLuckyBonusMultiplierSvga,
  setLuckyBonusMultiplierSvgaEnabled,
  updateLuckyBonusMultiplierSvga,
} from "@/app/settings/lucky-gifts/actions";
import { Loader2, Trash2, Film } from "lucide-react";
export type LuckyBonusMultiplierSvgaRow = {
  id: string;
  multiplier: number;
  label: string;
  svga_url: string;
  is_enabled: boolean;
  applies_to: "lucky" | "lucky_pro" | "both" | string;
};
export function LuckyBonusMultiplierSvgasPanel({ rows }: { rows: LuckyBonusMultiplierSvgaRow[] }) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [local, setLocal] = useState(rows);
  async function toggle(row: LuckyBonusMultiplierSvgaRow) {
    setBusyId(row.id);
    const next = !row.is_enabled;
    const res = await setLuckyBonusMultiplierSvgaEnabled(row.id, next);
    if (!res.success) alert(res.error);
    else {
      setLocal((prev) => prev.map((r) => (r.id === row.id ? { ...r, is_enabled: next } : r)));
    }
    setBusyId(null);
  }
  async function save(row: LuckyBonusMultiplierSvgaRow) {
    setBusyId(row.id);
    const res = await updateLuckyBonusMultiplierSvga({
      id: row.id,
      multiplier: Number(row.multiplier),
      label: row.label,
      applies_to: (row.applies_to as "lucky" | "lucky_pro" | "both") || "both",
      svga_url: row.svga_url,
    });
    if (!res.success) alert(res.error);
    setBusyId(null);
  }
  async function remove(row: LuckyBonusMultiplierSvgaRow) {
    if (!confirm(`Remove x${row.multiplier} SVGA?`)) return;
    setBusyId(row.id);
    const res = await deleteLuckyBonusMultiplierSvga(row.id);
    if (!res.success) alert(res.error);
    else setLocal((prev) => prev.filter((r) => r.id !== row.id));
    setBusyId(null);
  }
  function patch(id: string, patch: Partial<LuckyBonusMultiplierSvgaRow>) {
    setLocal((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));
  }
  return (
    <div className="glass-card p-8 space-y-6">
      <div className="flex items-center gap-3">
        <Film className="text-fuchsia-400" />
        <div>
          <h2 className="text-2xl font-black tracking-tight">Bonus multiplier SVGAs</h2>
          <p className="text-white/50 text-sm mt-1">
            Room float after Lucky / Lucky Pro win. File number = multiplier (x20 plays on 20x).
            Plays after the Lucky Pro banner if both would show — no overlap.
          </p>
        </div>
      </div>

      <div className="overflow-x-auto rounded-2xl border border-white/10">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-white/50 uppercase tracking-wider text-[11px]">
            <tr>
              <th className="text-left p-3">Multiplier</th>
              <th className="text-left p-3">Label</th>
              <th className="text-left p-3">Applies</th>
              <th className="text-left p-3">SVGA URL</th>
              <th className="text-left p-3">On</th>
              <th className="text-right p-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {local.map((row) => {
              const busy = busyId === row.id;
              return (
                <tr key={row.id} className="border-t border-white/5">
                  <td className="p-3">
                    <input
                      type="number"
                      className="w-20 bg-black/30 border border-white/10 rounded-lg px-2 py-1"
                      value={row.multiplier}
                      onChange={(e) => patch(row.id, { multiplier: Number(e.target.value) })}
                    />
                  </td>
                  <td className="p-3">
                    <input
                      className="w-24 bg-black/30 border border-white/10 rounded-lg px-2 py-1"
                      value={row.label}
                      onChange={(e) => patch(row.id, { label: e.target.value })}
                    />
                  </td>
                  <td className="p-3">
                    <select
                      className="bg-black/30 border border-white/10 rounded-lg px-2 py-1"
                      value={row.applies_to}
                      onChange={(e) => patch(row.id, { applies_to: e.target.value })}
                    >
                      <option value="both">Both</option>
                      <option value="lucky">Lucky</option>
                      <option value="lucky_pro">Lucky Pro</option>
                    </select>
                  </td>
                  <td className="p-3 min-w-[220px]">
                    <input
                      className="w-full bg-black/30 border border-white/10 rounded-lg px-2 py-1 text-xs"
                      value={row.svga_url}
                      onChange={(e) => patch(row.id, { svga_url: e.target.value })}
                    />
                  </td>
                  <td className="p-3">
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => toggle(row)}
                      className={`px-3 py-1 rounded-full text-xs font-bold ${
                        row.is_enabled
                          ? "bg-emerald-500/20 text-emerald-300"
                          : "bg-white/10 text-white/40"
                      }`}
                    >
                      {row.is_enabled ? "ON" : "OFF"}
                    </button>
                  </td>
                  <td className="p-3 text-right space-x-2 whitespace-nowrap">
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => save(row)}
                      className="px-3 py-1 rounded-lg bg-fuchsia-500/20 text-fuchsia-200 text-xs font-bold"
                    >
                      {busy ? <Loader2 className="inline animate-spin" size={14} /> : "Save"}
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => remove(row)}
                      className="px-2 py-1 rounded-lg bg-red-500/15 text-red-300"
                    >
                      <Trash2 size={14} />
                    </button>
                  </td>
                </tr>
              );
            })}
            {local.length === 0 && (
              <tr>
                <td colSpan={6} className="p-6 text-center text-white/40">
                  No multiplier SVGAs yet. Run seed script to upload.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
