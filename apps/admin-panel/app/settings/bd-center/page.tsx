import Link from "next/link";
import { ArrowLeft, Building2 } from "lucide-react";
import { BdGiftPackEditor } from "@/components/BdGiftPackEditor";
import { currentPeriodId } from "@/lib/salary-hub/constants";
import {
  addAgencySalaryLevel,
  addBdLevel,
  backfillStaffRoleCosmetics,
  executeAgencyPeriodPayout,
  executeBdMonthlyPayout,
  getGiftPolicySettings,
  listAgencySalaryLevels,
  listBdGiftPackSlots,
  listBdLevels,
  listStaffRoleCosmetics,
  updateAgencySalaryLevel,
  updateBdLevel,
  updateGiftHostPercent,
  updateStaffRoleCosmetics,
} from "./actions";
export default async function BdCenterSettingsPage() {
  const [agencyLevels, bdLevels, gift, cosmetics, giftSlots] = await Promise.all([
    listAgencySalaryLevels(),
    listBdLevels(),
    getGiftPolicySettings(),
    listStaffRoleCosmetics(),
    listBdGiftPackSlots(),
  ]);
  const periodId = currentPeriodId();
  const levelNumbers = (rows: { level: number | string }[]) => rows.map((r) => Number(r.level) || 0);
  const nextAgencyLevel = Math.max(0, ...levelNumbers(agencyLevels)) + 1;
  const nextBdLevel = Math.max(0, ...levelNumbers(bdLevels)) + 1;
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors"
      >
        <ArrowLeft size={18} />
        <span className="text-xs font-bold uppercase tracking-widest">Back</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-violet-500/20 border border-violet-500/20 flex items-center justify-center text-violet-300">
          <Building2 size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">BD / Agency Policy</h1>
          <p className="text-white/60 mt-2 max-w-2xl">
            Gift host %, Agency LV1–25 charm salaries, BD LV1–10 targets, Gift Pack (shop / upload /
            VIP days), Assistant/CS cosmetics, and settlement runs. Period A ends day 15 midnight;
            payouts auto on 16th &amp; 1st.
          </p>
        </div>
      </header>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-4">
        <h2 className="text-xl font-bold">Gift split</h2>
        <form action={updateGiftHostPercent} className="flex flex-wrap items-end gap-4">
          <label className="text-sm text-white/60">
            Host gift %
            <input
              name="host_gift_percent"
              type="number"
              min={0}
              max={100}
              defaultValue={gift?.host_gift_percent ?? 30}
              className="mt-1 block w-32 rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
          </label>
          <button className="rounded-xl bg-violet-500 px-4 py-2 font-bold text-sm">Save</button>
        </form>
        <p className="text-xs text-white/40">
          Remainder goes to platform. Agency/BD get $0 from gifts.
        </p>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-6">
        <div>
          <h2 className="text-xl font-bold">Assistant / CS tag &amp; frame</h2>
          <p className="text-sm text-white/50 mt-1">
            Paste shop item UUIDs (frame + tag/badge). Auto-granted when the role is assigned.
          </p>
        </div>
        {(cosmetics as any[]).map((row) => {
          const frame = Array.isArray(row.frame) ? row.frame[0] : row.frame;
          const tag = Array.isArray(row.tag) ? row.tag[0] : row.tag;
          return (
            <form
              key={row.role}
              action={updateStaffRoleCosmetics}
              className="rounded-2xl bg-black/30 p-4 space-y-3"
            >
              <input type="hidden" name="role" value={row.role} />
              <p className="font-bold capitalize">{String(row.role).replace("_", " ")}</p>
              <div className="grid md:grid-cols-2 gap-3">
                <label className="text-xs text-white/50 block">
                  Frame shop item ID
                  <input
                    name="frame_shop_item_id"
                    defaultValue={row.frame_shop_item_id ?? ""}
                    placeholder="uuid"
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                  />
                  {frame?.name && (
                    <span className="text-white/40 mt-1 block">Current: {frame.name}</span>
                  )}
                </label>
                <label className="text-xs text-white/50 block">
                  Tag / badge shop item ID
                  <input
                    name="tag_shop_item_id"
                    defaultValue={row.tag_shop_item_id ?? ""}
                    placeholder="uuid"
                    className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                  />
                  {tag?.name && (
                    <span className="text-white/40 mt-1 block">Current: {tag.name}</span>
                  )}
                </label>
              </div>
              <label className="text-xs text-white/50 block max-w-xs">
                Duration days (empty = permanent)
                <input
                  name="duration_days"
                  type="number"
                  min={1}
                  defaultValue={row.duration_days ?? ""}
                  className="mt-1 w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
                />
              </label>
              <div className="flex flex-wrap gap-2">
                <button className="rounded-xl bg-violet-500 px-4 py-2 font-bold text-sm">
                  Save
                </button>
              </div>
            </form>
          );
        })}
        <form action={backfillStaffRoleCosmetics} className="flex flex-wrap gap-2 items-center">
          <input type="hidden" name="role" value="" />
          <button className="rounded-xl bg-amber-500/80 text-black px-4 py-2 font-bold text-sm">
            Grant cosmetics to all current Assistant + CS
          </button>
        </form>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-4">
        <h2 className="text-xl font-bold">Settlements</h2>
        <div className="grid md:grid-cols-2 gap-4">
          <form
            action={executeAgencyPeriodPayout}
            className="space-y-3 rounded-2xl bg-black/30 p-4"
          >
            <p className="text-sm text-white/60">Agency period payout (owner wallet)</p>
            <input
              name="period_id"
              defaultValue={periodId}
              className="w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
            <button className="rounded-xl bg-emerald-500/80 px-4 py-2 font-bold text-sm">
              Run agency payout
            </button>
          </form>
          <form action={executeBdMonthlyPayout} className="space-y-3 rounded-2xl bg-black/30 p-4">
            <p className="text-sm text-white/60">BD monthly payout (whole month, auto-paid on 1st, PK)</p>
            <input
              name="period_yyyy_mm"
              defaultValue={periodId}
              className="w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2"
            />
            <button className="rounded-xl bg-sky-500/80 px-4 py-2 font-bold text-sm">
              Run BD payout
            </button>
          </form>
        </div>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-4 overflow-x-auto">
        <h2 className="text-xl font-bold">Agency salary levels</h2>
        <table className="w-full text-sm">
          <thead className="text-white/40 text-left">
            <tr>
              <th className="py-2">LV</th>
              <th>Charm target</th>
              <th>Charm $</th>
              <th>Agent $</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {agencyLevels.map((row: any) => (
              <tr key={row.level} className="border-t border-white/5">
                <td className="py-2 font-bold">{row.level}</td>
                <td>
                  <form
                    action={updateAgencySalaryLevel}
                    className="flex flex-wrap gap-2 items-center"
                  >
                    <input type="hidden" name="level" value={row.level} />
                    <input
                      name="charm_target"
                      defaultValue={row.charm_target}
                      className="w-28 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
                    />
                    <input
                      name="charm_salary_usd"
                      defaultValue={row.charm_salary_usd}
                      className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
                    />
                    <input
                      name="agent_salary_usd"
                      defaultValue={row.agent_salary_usd}
                      className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
                    />
                    <button className="text-violet-300 text-xs font-bold">Save</button>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <form
          action={addAgencySalaryLevel}
          className="flex flex-wrap gap-2 items-center border-t border-white/10 pt-4"
        >
          <span className="text-sm font-bold text-white/60 mr-2">Add level {nextAgencyLevel}</span>
          <input
            name="charm_target"
            required
            placeholder="Charm target"
            className="w-28 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
          />
          <input
            name="charm_salary_usd"
            required
            placeholder="Charm $"
            className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
          />
          <input
            name="agent_salary_usd"
            required
            placeholder="Agent $"
            className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
          />
          <button className="rounded-lg bg-violet-500/80 px-3 py-1 text-xs font-bold">
            + Add level
          </button>
        </form>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6">
        <BdGiftPackEditor
          levels={(bdLevels as any[])
            .filter((r) => r.level > 0)
            .map((r) => ({
              level: r.level as number,
              badge_url: (r.badge_url as string | null) ?? null,
            }))}
          slots={giftSlots}
        />
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-6 space-y-4 overflow-x-auto">
        <h2 className="text-xl font-bold">BD levels</h2>
        <table className="w-full text-sm">
          <thead className="text-white/40 text-left">
            <tr>
              <th className="py-2">LV</th>
              <th>Agency target $</th>
              <th>Basic</th>
              <th>Comm</th>
              <th>New BD</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {bdLevels
              .filter((r: any) => r.level > 0)
              .map((row: any) => (
                <tr key={row.level} className="border-t border-white/5">
                  <td className="py-2 font-bold">{row.level}</td>
                  <td colSpan={5}>
                    <form action={updateBdLevel} className="flex flex-wrap gap-2 items-center">
                      <input type="hidden" name="level" value={row.level} />
                      <input
                        name="agency_target_usd"
                        defaultValue={row.agency_target_usd}
                        className="w-24 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
                      />
                      <input
                        name="basic_salary_usd"
                        defaultValue={row.basic_salary_usd}
                        className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
                      />
                      <input
                        name="commission_usd"
                        defaultValue={row.commission_usd}
                        className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
                      />
                      <input
                        name="new_bd_commission_usd"
                        defaultValue={row.new_bd_commission_usd}
                        className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
                      />
                      <button className="text-sky-300 text-xs font-bold">Save</button>
                    </form>
                  </td>
                </tr>
              ))}
          </tbody>
        </table>
        <form
          action={addBdLevel}
          className="flex flex-wrap gap-2 items-center border-t border-white/10 pt-4"
        >
          <span className="text-sm font-bold text-white/60 mr-2">Add level {nextBdLevel}</span>
          <input
            name="agency_target_usd"
            required
            placeholder="Agency target $"
            className="w-24 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
          />
          <input
            name="basic_salary_usd"
            required
            placeholder="Basic"
            className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
          />
          <input
            name="commission_usd"
            required
            placeholder="Comm"
            className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
          />
          <input
            name="new_bd_commission_usd"
            required
            placeholder="New BD"
            className="w-20 rounded-lg bg-black/40 border border-white/10 px-2 py-1"
          />
          <button className="rounded-lg bg-sky-500/80 px-3 py-1 text-xs font-bold">
            + Add level
          </button>
        </form>
      </section>
    </div>
  );
}
