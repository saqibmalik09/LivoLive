"use client";
import { useState } from "react";
import { Plus, Trash2, Save } from "lucide-react";
import { toast } from "sonner";
import {
  deleteLuckyBagTier,
  updateLuckyBagRules,
  upsertLuckyBagTier,
  type LuckyBagTierInput,
} from "@/lib/actions/lucky-bags";
const RECIPIENT_OPTIONS = [5, 10, 20, 30];
type TierRow = LuckyBagTierInput & {
  id?: string;
};
interface LuckyBagSettingsFormProps {
  initialTiers: TierRow[];
  initialRules: string[];
}
export function LuckyBagSettingsForm({ initialTiers, initialRules }: LuckyBagSettingsFormProps) {
  const [tiers, setTiers] = useState<TierRow[]>(initialTiers);
  const [rules, setRules] = useState<string[]>(
    initialRules.length > 0
      ? initialRules
      : [
          "Lucky bags can be sent to other users. Room lucky bags are only displayed and collected in the current room.",
          "World blessing bags are displayed outside the room with a floating banner. Tap it to enter the room and claim.",
          "Choose the bag amount and number of recipients. Claimers randomly receive gold coins from the pool.",
          "Sending lucky bags does not increase charm value.",
        ],
  );
  const [savingRules, setSavingRules] = useState(false);
  const saveTier = async (tier: TierRow, index: number) => {
    try {
      await upsertLuckyBagTier(tier);
      toast.success(`Tier ${tier.label} saved`);
      if (!tier.id) {
        window.location.reload();
      }
    } catch (e: any) {
      toast.error(e.message);
    }
  };
  const removeTier = async (id: string | undefined, index: number) => {
    if (id) {
      try {
        await deleteLuckyBagTier(id);
        setTiers((prev) => prev.filter((_, i) => i !== index));
        toast.success("Tier deleted");
      } catch (e: any) {
        toast.error(e.message);
      }
    } else {
      setTiers((prev) => prev.filter((_, i) => i !== index));
    }
  };
  const saveRules = async () => {
    setSavingRules(true);
    try {
      await updateLuckyBagRules(rules.filter((r) => r.trim().length > 0));
      toast.success("Rules updated");
    } catch (e: any) {
      toast.error(e.message);
    } finally {
      setSavingRules(false);
    }
  };
  return (
    <div className="space-y-10">
      <section className="glass-card border border-white/10 p-6 space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-white">Bag Tiers</h2>
          <button
            type="button"
            onClick={() =>
              setTiers((prev) => [
                ...prev,
                {
                  label: "New",
                  total_coins: 1000,
                  recipient_options: [5, 10, 20, 30],
                  is_active: true,
                  sort_order: prev.length + 1,
                },
              ])
            }
            className="flex items-center gap-2 rounded-xl bg-pink-500/20 px-4 py-2 text-xs font-bold uppercase tracking-widest text-pink-300"
          >
            <Plus size={14} /> Add Tier
          </button>
        </div>

        {tiers.map((tier, index) => (
          <div
            key={tier.id ?? `new-${index}`}
            className="grid gap-4 rounded-2xl border border-white/10 bg-black/20 p-4 md:grid-cols-2"
          >
            <label className="block text-sm text-white/60">
              Label
              <input
                value={tier.label}
                onChange={(e) =>
                  setTiers((prev) =>
                    prev.map((t, i) => (i === index ? { ...t, label: e.target.value } : t)),
                  )
                }
                className="mt-1 w-full rounded-xl border border-white/10 bg-black/40 px-3 py-2 text-white"
              />
            </label>
            <label className="block text-sm text-white/60">
              Total coins
              <input
                type="number"
                value={tier.total_coins}
                onChange={(e) =>
                  setTiers((prev) =>
                    prev.map((t, i) =>
                      i === index ? { ...t, total_coins: parseInt(e.target.value) || 0 } : t,
                    ),
                  )
                }
                className="mt-1 w-full rounded-xl border border-white/10 bg-black/40 px-3 py-2 text-white"
              />
            </label>
            <label className="block text-sm text-white/60 md:col-span-2">
              Recipient options
              <div className="mt-2 flex flex-wrap gap-3">
                {RECIPIENT_OPTIONS.map((opt) => (
                  <label key={opt} className="flex items-center gap-2 text-white/80">
                    <input
                      type="checkbox"
                      checked={tier.recipient_options.includes(opt)}
                      onChange={(e) =>
                        setTiers((prev) =>
                          prev.map((t, i) => {
                            if (i !== index) return t;
                            const next = e.target.checked
                              ? [...t.recipient_options, opt]
                              : t.recipient_options.filter((v) => v !== opt);
                            return {
                              ...t,
                              recipient_options: next.sort((a, b) => a - b),
                            };
                          }),
                        )
                      }
                    />
                    {opt}
                  </label>
                ))}
              </div>
            </label>
            <div className="flex items-end gap-3 md:col-span-2">
              <label className="flex items-center gap-2 text-sm text-white/70">
                <input
                  type="checkbox"
                  checked={tier.is_active}
                  onChange={(e) =>
                    setTiers((prev) =>
                      prev.map((t, i) => (i === index ? { ...t, is_active: e.target.checked } : t)),
                    )
                  }
                />
                Active
              </label>
              <button
                type="button"
                onClick={() => saveTier(tier, index)}
                className="rounded-xl bg-amber-500/20 px-4 py-2 text-xs font-bold text-amber-300"
              >
                Save tier
              </button>
              <button
                type="button"
                onClick={() => removeTier(tier.id, index)}
                className="rounded-xl bg-red-500/20 p-2 text-red-300"
              >
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        ))}
      </section>

      <section className="glass-card border border-white/10 p-6 space-y-4">
        <h2 className="text-xl font-bold text-white">Rules (in-app)</h2>
        {rules.map((rule, index) => (
          <textarea
            key={index}
            value={rule}
            onChange={(e) =>
              setRules((prev) => prev.map((r, i) => (i === index ? e.target.value : r)))
            }
            rows={3}
            className="w-full rounded-xl border border-white/10 bg-black/40 px-3 py-2 text-white"
          />
        ))}
        <button
          type="button"
          onClick={() => setRules((prev) => [...prev, ""])}
          className="text-xs font-bold uppercase tracking-widest text-white/40"
        >
          + Add rule
        </button>
        <button
          type="button"
          disabled={savingRules}
          onClick={saveRules}
          className="flex items-center gap-2 rounded-xl bg-pink-500 px-5 py-3 text-sm font-bold text-white"
        >
          <Save size={16} /> Save rules
        </button>
      </section>
    </div>
  );
}
