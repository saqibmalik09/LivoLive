"use client";
import { useState } from "react";
import {
  updateLuckyGiftConfig,
  updateLuckyProGiftConfig,
} from "@/app/settings/lucky-gifts/actions";
import { Save, Loader2, Sparkles, Percent, Gift, Coins, Shuffle } from "lucide-react";
type BonusTriggerMode = "same_receiver" | "random" | "both";
type GiftVariant = "lucky" | "lucky_pro";
interface LuckyGiftConfigFormProps {
  variant: GiftVariant;
  config: {
    receiver_percent: number;
    gifts_for_bonus_min: number;
    gifts_for_bonus_max: number;
    bonus_multiplier_min: number;
    bonus_multiplier_max: number;
    bonus_chance_percent: number;
    bonus_trigger_mode?: string;
  };
}
const MODE_OPTIONS: {
  value: BonusTriggerMode;
  label: string;
  hint: string;
}[] = [
  {
    value: "same_receiver",
    label: "Same person only",
    hint: "3–4 lucky gifts to the same user → one bonus → counter resets to 0. Next bonus needs 3–4 gifts again.",
  },
  {
    value: "random",
    label: "Any receiver (total count)",
    hint: "3–4 lucky gifts to anyone (mixed users) → one bonus → reset. Not bonus on every gift.",
  },
  {
    value: "both",
    label: "Any receiver (same as random)",
    hint: "Counts total lucky gifts to different users. Resets after each bonus streak.",
  },
];
const VARIANT_META: Record<
  GiftVariant,
  {
    title: string;
    subtitle: string;
    accentText: string;
    accentBorder: string;
    accentBg: string;
    buttonClass: string;
    saveLabel: string;
  }
> = {
  lucky: {
    title: "Lucky gift rules",
    subtitle:
      "Lucky category gifts: receiver gets small diamond %. Coin bonus goes to the sender (who paid for the gift).",
    accentText: "text-amber-400",
    accentBorder: "border-amber-500",
    accentBg: "bg-amber-500/10",
    buttonClass: "bg-amber-500 hover:bg-amber-400 text-black",
    saveLabel: "Save lucky gift settings",
  },
  lucky_pro: {
    title: "Lucky Pro gift rules",
    subtitle:
      "Lucky Pro category gifts: higher-tier bonus rules. Receiver gets diamond %. Coin bonus goes to the sender.",
    accentText: "text-violet-400",
    accentBorder: "border-violet-500",
    accentBg: "bg-violet-500/10",
    buttonClass: "bg-violet-500 hover:bg-violet-400 text-white",
    saveLabel: "Save lucky pro gift settings",
  },
};
export function LuckyGiftConfigForm({ variant, config }: LuckyGiftConfigFormProps) {
  const meta = VARIANT_META[variant];
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    receiver_percent: Number(config.receiver_percent),
    gifts_for_bonus_min: config.gifts_for_bonus_min,
    gifts_for_bonus_max: config.gifts_for_bonus_max,
    bonus_multiplier_min: Number(config.bonus_multiplier_min),
    bonus_multiplier_max: Number(config.bonus_multiplier_max),
    bonus_chance_percent: config.bonus_chance_percent,
    bonus_trigger_mode: (config.bonus_trigger_mode as BonusTriggerMode) || "same_receiver",
  });
  function setField(key: keyof typeof form, value: string) {
    setForm((prev) => ({ ...prev, [key]: value === "" ? "" : Number(value) }));
  }
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    const payload = {
      receiver_percent: Number(form.receiver_percent),
      gifts_for_bonus_min: Number(form.gifts_for_bonus_min),
      gifts_for_bonus_max: Number(form.gifts_for_bonus_max),
      bonus_multiplier_min: Number(form.bonus_multiplier_min),
      bonus_multiplier_max: Number(form.bonus_multiplier_max),
      bonus_chance_percent: Number(form.bonus_chance_percent),
      bonus_trigger_mode: form.bonus_trigger_mode,
    };
    const res =
      variant === "lucky_pro"
        ? await updateLuckyProGiftConfig(payload)
        : await updateLuckyGiftConfig(payload);
    if (!res.success) alert("Error: " + res.error);
    setLoading(false);
  }
  const selectedMode = MODE_OPTIONS.find((m) => m.value === form.bonus_trigger_mode);
  return (
    <form onSubmit={handleSubmit} className="glass-card p-10 space-y-10">
      <div className="flex items-center gap-3">
        <Sparkles className={meta.accentText} />
        <div>
          <h3 className="text-lg font-black tracking-tight uppercase">{meta.title}</h3>
          <p className="text-xs text-white/40 mt-1">{meta.subtitle}</p>
        </div>
      </div>

      <div className="space-y-4 p-6 rounded-2xl bg-white/5 border border-white/10">
        <div
          className={`flex items-center gap-2 text-[10px] font-black uppercase tracking-widest ${meta.accentText}`}
        >
          <Shuffle size={14} /> Bonus trigger mode
        </div>
        <div className="grid grid-cols-1 gap-3">
          {MODE_OPTIONS.map((opt) => (
            <label
              key={opt.value}
              className={`flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-all ${
                form.bonus_trigger_mode === opt.value
                  ? `${meta.accentBorder} ${meta.accentBg}`
                  : "border-white/10 hover:border-white/20"
              }`}
            >
              <input
                type="radio"
                name={`bonus_trigger_mode_${variant}`}
                value={opt.value}
                checked={form.bonus_trigger_mode === opt.value}
                onChange={() => setForm((p) => ({ ...p, bonus_trigger_mode: opt.value }))}
                className="mt-1"
              />
              <div>
                <p className="font-bold text-sm text-white">{opt.label}</p>
                <p className="text-xs text-white/40 mt-1">{opt.hint}</p>
              </div>
            </label>
          ))}
        </div>
        {selectedMode && (
          <p className="text-[10px] text-white/30 italic">Active: {selectedMode.hint}</p>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="space-y-2">
          <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
            <Percent size={10} /> Receiver diamond %
          </label>
          <input
            type="number"
            step="0.1"
            min={1}
            max={10}
            required
            value={form.receiver_percent}
            onChange={(e) => setField("receiver_percent", e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 font-mono text-xl font-black"
          />
        </div>

        <div className="space-y-2">
          <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
            <Gift size={10} /> Bonus win chance %
          </label>
          <input
            type="number"
            min={0}
            max={100}
            required
            value={form.bonus_chance_percent}
            onChange={(e) => setField("bonus_chance_percent", e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 font-mono text-xl font-black"
          />
          <p className="text-[10px] text-white/30 px-1">
            Used for same-person streak and random mode.
          </p>
        </div>

        <div className="space-y-2">
          <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
            Gifts until bonus (min) — same person
          </label>
          <input
            type="number"
            min={1}
            required
            value={form.gifts_for_bonus_min}
            onChange={(e) => setField("gifts_for_bonus_min", e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 font-mono text-xl font-black"
          />
        </div>

        <div className="space-y-2">
          <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
            Gifts until bonus (max) — same person
          </label>
          <input
            type="number"
            min={form.gifts_for_bonus_min as number}
            required
            value={form.gifts_for_bonus_max}
            onChange={(e) => setField("gifts_for_bonus_max", e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 font-mono text-xl font-black"
          />
        </div>

        <div className="space-y-2">
          <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1 flex items-center gap-2">
            <Coins size={10} /> Bonus multiplier min (× gift value)
          </label>
          <input
            type="number"
            step="0.1"
            min={1.1}
            required
            value={form.bonus_multiplier_min}
            onChange={(e) => setField("bonus_multiplier_min", e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 font-mono text-xl font-black"
          />
        </div>

        <div className="space-y-2">
          <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
            Bonus multiplier max (× gift value)
          </label>
          <input
            type="number"
            step="0.1"
            min={form.bonus_multiplier_min as number}
            required
            value={form.bonus_multiplier_max}
            onChange={(e) => setField("bonus_multiplier_max", e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 font-mono text-xl font-black"
          />
        </div>
      </div>

      <button
        type="submit"
        disabled={loading}
        className={`w-full py-5 font-black rounded-2xl flex items-center justify-center gap-3 disabled:opacity-50 ${meta.buttonClass}`}
      >
        {loading ? <Loader2 size={24} className="animate-spin" /> : <Save size={24} />}
        {meta.saveLabel}
      </button>
    </form>
  );
}
