"use client";
import { useMemo, useState } from "react";
import { Loader2, Plus, Save, Trash2 } from "lucide-react";
import { saveTaskWheelTiers, type TaskWheelTierInput } from "./actions";
type Row = TaskWheelTierInput & {
  key: string;
};
function newKey() {
  return `k-${Math.random().toString(36).slice(2, 9)}`;
}
export function TaskWheelConfigClient({ initialTiers }: { initialTiers: TaskWheelTierInput[] }) {
  const [rows, setRows] = useState<Row[]>(() =>
    (initialTiers.length
      ? initialTiers
      : [
          {
            min_coins: 100,
            max_coins: 300,
            weight_percent: 40,
            label: "100-300",
            sort_order: 1,
            is_active: true,
          },
          {
            min_coins: 301,
            max_coins: 600,
            weight_percent: 35,
            label: "301-600",
            sort_order: 2,
            is_active: true,
          },
          {
            min_coins: 601,
            max_coins: 1000,
            weight_percent: 25,
            label: "601-1K",
            sort_order: 3,
            is_active: true,
          },
        ]
    ).map((t) => ({ ...t, key: t.id || newKey() })),
  );
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const totalPct = useMemo(
    () => rows.filter((r) => r.is_active).reduce((s, r) => s + (Number(r.weight_percent) || 0), 0),
    [rows],
  );
  const update = (key: string, patch: Partial<Row>) => {
    setRows((prev) => prev.map((r) => (r.key === key ? { ...r, ...patch } : r)));
    setMessage(null);
  };
  const addRow = () => {
    setRows((prev) => [
      ...prev,
      {
        key: newKey(),
        min_coins: 100,
        max_coins: 500,
        weight_percent: 10,
        label: "",
        sort_order: prev.length + 1,
        is_active: true,
      },
    ]);
  };
  const removeRow = (key: string) => {
    setRows((prev) => prev.filter((r) => r.key !== key));
  };
  const onSave = async () => {
    setSaving(true);
    setMessage(null);
    const payload: TaskWheelTierInput[] = rows.map((r, i) => ({
      id: r.id,
      min_coins: Number(r.min_coins),
      max_coins: Number(r.max_coins),
      weight_percent: Number(r.weight_percent),
      label: r.label?.trim() || `${r.min_coins}-${r.max_coins}`,
      sort_order: i + 1,
      is_active: r.is_active,
    }));
    const res = await saveTaskWheelTiers(payload);
    setSaving(false);
    if (!res.success) {
      setMessage(res.error || "Save failed");
      return;
    }
    setMessage("Saved. New spins use this config immediately.");
  };
  return (
    <div className="space-y-6">
      <div className="glass-card space-y-3">
        <p className="text-sm text-white/60 leading-relaxed">
          Each spin picks a tier by <strong className="text-white/80">percentage</strong>, then
          gives a <strong className="text-white/80">random coin amount</strong> between that
          tier&apos;s min and max. Active percents must total{" "}
          <strong className="text-amber-300">100%</strong>.
        </p>
        <p
          className={`text-sm font-bold ${Math.abs(totalPct - 100) <= 0.5 ? "text-emerald-400" : "text-amber-400"}`}
        >
          Active total: {totalPct.toFixed(2)}%
        </p>
      </div>

      <div className="space-y-3">
        {rows.map((row, idx) => (
          <div key={row.key} className="glass-card grid grid-cols-2 md:grid-cols-7 gap-3 items-end">
            <label className="flex flex-col gap-1 text-[10px] font-black uppercase tracking-widest text-white/40">
              Min coins
              <input
                type="number"
                value={row.min_coins}
                onChange={(e) => update(row.key, { min_coins: Number(e.target.value) })}
                className="bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm text-white"
              />
            </label>
            <label className="flex flex-col gap-1 text-[10px] font-black uppercase tracking-widest text-white/40">
              Max coins
              <input
                type="number"
                value={row.max_coins}
                onChange={(e) => update(row.key, { max_coins: Number(e.target.value) })}
                className="bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm text-white"
              />
            </label>
            <label className="flex flex-col gap-1 text-[10px] font-black uppercase tracking-widest text-white/40">
              Percent %
              <input
                type="number"
                step="0.01"
                value={row.weight_percent}
                onChange={(e) => update(row.key, { weight_percent: Number(e.target.value) })}
                className="bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm text-white"
              />
            </label>
            <label className="flex flex-col gap-1 text-[10px] font-black uppercase tracking-widest text-white/40 md:col-span-2">
              Wheel label
              <input
                type="text"
                value={row.label}
                onChange={(e) => update(row.key, { label: e.target.value })}
                placeholder={`${row.min_coins}-${row.max_coins}`}
                className="bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm text-white"
              />
            </label>
            <label className="flex items-center gap-2 text-[11px] font-bold text-white/70 pb-2">
              <input
                type="checkbox"
                checked={row.is_active}
                onChange={(e) => update(row.key, { is_active: e.target.checked })}
              />
              Active
            </label>
            <button
              type="button"
              onClick={() => removeRow(row.key)}
              className="inline-flex items-center justify-center gap-2 px-3 py-2 rounded-xl border border-red-500/30 text-red-300 text-[11px] font-black uppercase tracking-wider hover:bg-red-500/10"
              title={`Remove tier ${idx + 1}`}
            >
              <Trash2 size={14} />
              Remove
            </button>
          </div>
        ))}
      </div>

      <div className="flex flex-wrap gap-3">
        <button
          type="button"
          onClick={addRow}
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl border border-white/15 bg-white/5 text-[11px] font-black uppercase tracking-wider text-white/80 hover:bg-white/10"
        >
          <Plus size={14} />
          Add tier
        </button>
        <button
          type="button"
          onClick={onSave}
          disabled={saving}
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-amber-500 text-black text-[11px] font-black uppercase tracking-wider disabled:opacity-50"
        >
          {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
          Save config
        </button>
      </div>

      {message && (
        <p
          className={`text-sm font-medium ${message.startsWith("Saved") ? "text-emerald-400" : "text-red-400"}`}
        >
          {message}
        </p>
      )}
    </div>
  );
}
