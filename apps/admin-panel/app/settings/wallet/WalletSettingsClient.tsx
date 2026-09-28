"use client";
import { useState } from "react";
import { Loader2, Save, CheckCircle2 } from "lucide-react";
import {
  updateCashExchangeConfig,
  updateDiamondSalaryConfig,
  updateWithdrawalConfig,
  updatePaymentMethods,
} from "./actions";
const DEFAULT_DAYS = [1, 2, 3, 4, 5, 16, 17, 18, 19, 20];
export function WalletSettingsClient({
  cashConfig,
  salaryConfig,
  withdrawConfig,
  paymentMethods,
}: {
  cashConfig: any | null;
  salaryConfig: any | null;
  withdrawConfig: any | null;
  paymentMethods: string[];
}) {
  return (
    <div className="space-y-10">
      <CashExchangeCard config={cashConfig} />
      <DiamondSalaryCard config={salaryConfig} />
      <WithdrawalRulesCard config={withdrawConfig} />
      <PaymentMethodsCard initialMethods={paymentMethods} />
    </div>
  );
}
function SaveButton({
  loading,
  success,
  label = "Save",
}: {
  loading: boolean;
  success: boolean;
  label?: string;
}) {
  return (
    <button
      type="submit"
      disabled={loading}
      className="px-6 py-3 rounded-xl bg-violet-500 text-black text-xs font-black uppercase tracking-widest flex items-center gap-2 disabled:opacity-50"
    >
      {loading ? (
        <Loader2 size={14} className="animate-spin" />
      ) : success ? (
        <CheckCircle2 size={14} />
      ) : (
        <Save size={14} />
      )}
      {success ? "Saved" : label}
    </button>
  );
}
function CashExchangeCard({ config }: { config: any | null }) {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setSuccess(false);
    const fd = new FormData(e.currentTarget);
    const res = await updateCashExchangeConfig(config?.id ?? null, {
      coins_per_dollar: parseInt(String(fd.get("coins_per_dollar")), 10),
      bonus_percent: parseFloat(String(fd.get("bonus_percent"))),
      is_active: fd.get("is_active") === "on",
    });
    setLoading(false);
    if (!res.success) return alert(res.error);
    setSuccess(true);
    setTimeout(() => setSuccess(false), 2500);
  }
  return (
    <form onSubmit={onSubmit} className="glass-card space-y-6">
      <div>
        <h2 className="text-xl font-black">Cash → Gold Coins</h2>
        <p className="text-white/40 text-sm mt-1">
          Balance tab exchange rate (USD to coins + bonus)
        </p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Field
          label="Coins per $1"
          name="coins_per_dollar"
          type="number"
          defaultValue={config?.coins_per_dollar ?? 68000}
        />
        <Field
          label="Bonus %"
          name="bonus_percent"
          type="number"
          step="0.01"
          defaultValue={config?.bonus_percent ?? 32}
        />
        <ActiveToggle defaultChecked={config?.is_active ?? true} />
      </div>
      <SaveButton loading={loading} success={success} />
    </form>
  );
}
function DiamondSalaryCard({ config }: { config: any | null }) {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setSuccess(false);
    const fd = new FormData(e.currentTarget);
    const res = await updateDiamondSalaryConfig(config?.id ?? null, {
      diamonds_unit: parseInt(String(fd.get("diamonds_unit")), 10),
      usd_per_unit: parseFloat(String(fd.get("usd_per_unit"))),
      is_active: fd.get("is_active") === "on",
    });
    setLoading(false);
    if (!res.success) return alert(res.error);
    setSuccess(true);
    setTimeout(() => setSuccess(false), 2500);
  }
  return (
    <form onSubmit={onSubmit} className="glass-card space-y-6">
      <div>
        <h2 className="text-xl font-black">Diamonds → Salary Wallet</h2>
        <p className="text-white/40 text-sm mt-1">Example: 150000 diamonds = $0.75 cash balance</p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Field
          label="Diamonds unit (block)"
          name="diamonds_unit"
          type="number"
          defaultValue={config?.diamonds_unit ?? 150000}
        />
        <Field
          label="USD per unit"
          name="usd_per_unit"
          type="number"
          step="0.0001"
          defaultValue={config?.usd_per_unit ?? 0.75}
        />
        <ActiveToggle defaultChecked={config?.is_active ?? true} />
      </div>
      <SaveButton loading={loading} success={success} />
    </form>
  );
}
function WithdrawalRulesCard({ config }: { config: any | null }) {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const initialDays: number[] = Array.isArray(config?.allowed_days)
    ? config.allowed_days.map((d: any) => Number(d))
    : DEFAULT_DAYS;
  const [days, setDays] = useState<number[]>(initialDays);
  function toggleDay(day: number) {
    setDays((prev) =>
      prev.includes(day) ? prev.filter((d) => d !== day) : [...prev, day].sort((a, b) => a - b),
    );
  }
  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setSuccess(false);
    const fd = new FormData(e.currentTarget);
    const res = await updateWithdrawalConfig(config?.id ?? null, {
      fee_percent: parseFloat(String(fd.get("fee_percent"))),
      min_amount: parseFloat(String(fd.get("min_amount"))),
      allowed_days: days,
      timezone_offset_hours: parseInt(String(fd.get("timezone_offset_hours")), 10),
      is_active: fd.get("is_active") === "on",
    });
    setLoading(false);
    if (!res.success) return alert(res.error);
    setSuccess(true);
    setTimeout(() => setSuccess(false), 2500);
  }
  return (
    <form onSubmit={onSubmit} className="glass-card space-y-6">
      <div>
        <h2 className="text-xl font-black">Withdrawal Rules</h2>
        <p className="text-white/40 text-sm mt-1">
          Fee, minimum amount, and allowed calendar days (UTC offset)
        </p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Field
          label="Fee %"
          name="fee_percent"
          type="number"
          step="0.01"
          defaultValue={config?.fee_percent ?? 0}
        />
        <Field
          label="Min amount ($)"
          name="min_amount"
          type="number"
          step="0.01"
          defaultValue={config?.min_amount ?? 1}
        />
        <Field
          label="Timezone offset (hours)"
          name="timezone_offset_hours"
          type="number"
          defaultValue={config?.timezone_offset_hours ?? 3}
        />
      </div>
      <div>
        <p className="text-[10px] font-bold uppercase text-white/30 tracking-widest mb-3">
          Allowed days of month
        </p>
        <div className="flex flex-wrap gap-2">
          {Array.from({ length: 31 }, (_, i) => i + 1).map((day) => {
            const on = days.includes(day);
            return (
              <button
                key={day}
                type="button"
                onClick={() => toggleDay(day)}
                className={`w-9 h-9 rounded-lg text-xs font-black ${
                  on ? "bg-violet-500 text-black" : "bg-white/5 text-white/40 hover:text-white"
                }`}
              >
                {day}
              </button>
            );
          })}
        </div>
      </div>
      <ActiveToggle defaultChecked={config?.is_active ?? true} />
      <SaveButton loading={loading} success={success} />
    </form>
  );
}
function PaymentMethodsCard({ initialMethods }: { initialMethods: string[] }) {
  const [methods, setMethods] = useState(initialMethods);
  const [newMethod, setNewMethod] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  async function save() {
    setLoading(true);
    setSuccess(false);
    const res = await updatePaymentMethods(methods);
    setLoading(false);
    if (!res.success) return alert(res.error);
    setSuccess(true);
    setTimeout(() => setSuccess(false), 2500);
  }
  return (
    <div className="glass-card space-y-6">
      <div>
        <h2 className="text-xl font-black">Payment Methods</h2>
        <p className="text-white/40 text-sm mt-1">Options users can pick when withdrawing cash</p>
      </div>
      <div className="flex gap-3">
        <input
          value={newMethod}
          onChange={(e) => setNewMethod(e.target.value)}
          placeholder="e.g. JazzCash"
          className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm font-bold outline-none focus:border-violet-500"
        />
        <button
          type="button"
          onClick={() => {
            const v = newMethod.trim();
            if (!v || methods.includes(v)) return;
            setMethods([...methods, v]);
            setNewMethod("");
          }}
          className="px-5 rounded-xl bg-white/10 text-xs font-black uppercase tracking-widest"
        >
          Add
        </button>
      </div>
      <div className="flex flex-wrap gap-2">
        {methods.map((m) => (
          <button
            key={m}
            type="button"
            onClick={() => setMethods(methods.filter((x) => x !== m))}
            className="px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-sm font-bold hover:border-red-400/40"
            title="Click to remove"
          >
            {m} ×
          </button>
        ))}
      </div>
      <button
        type="button"
        onClick={save}
        disabled={loading}
        className="px-6 py-3 rounded-xl bg-violet-500 text-black text-xs font-black uppercase tracking-widest flex items-center gap-2 disabled:opacity-50"
      >
        {loading ? (
          <Loader2 size={14} className="animate-spin" />
        ) : success ? (
          <CheckCircle2 size={14} />
        ) : (
          <Save size={14} />
        )}
        {success ? "Saved" : "Save methods"}
      </button>
    </div>
  );
}
function Field({
  label,
  name,
  type = "text",
  step,
  defaultValue,
}: {
  label: string;
  name: string;
  type?: string;
  step?: string;
  defaultValue?: string | number;
}) {
  return (
    <div className="space-y-2">
      <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
        {label}
      </label>
      <input
        required
        name={name}
        type={type}
        step={step}
        defaultValue={defaultValue as any}
        className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 font-mono text-sm outline-none focus:border-violet-500"
      />
    </div>
  );
}
function ActiveToggle({ defaultChecked }: { defaultChecked: boolean }) {
  return (
    <div className="flex items-center justify-between p-4 rounded-xl bg-white/5 border border-white/5">
      <div>
        <p className="text-sm font-bold">Active</p>
        <p className="text-xs text-white/30">Disable to hide from app</p>
      </div>
      <label className="relative inline-flex items-center cursor-pointer">
        <input
          type="checkbox"
          name="is_active"
          defaultChecked={defaultChecked}
          className="sr-only peer"
        />
        <div className="w-12 h-6 bg-white/10 rounded-full peer peer-checked:after:translate-x-full after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white/50 after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-violet-500 peer-checked:after:bg-white" />
      </label>
    </div>
  );
}
