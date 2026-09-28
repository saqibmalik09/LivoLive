import { supabaseAdmin } from "@/lib/supabase";
import { LuckyGiftConfigForm } from "@/components/LuckyGiftConfigForm";
import {
  LuckyBonusMultiplierSvgasPanel,
  type LuckyBonusMultiplierSvgaRow,
} from "@/components/LuckyBonusMultiplierSvgasPanel";
import { LuckyRoomWinSvgaToggle } from "@/components/LuckyRoomWinSvgaToggle";
import { LuckyDailyCapResetPanel } from "@/components/LuckyDailyCapResetPanel";
import { ArrowLeft, Sparkles } from "lucide-react";
import Link from "next/link";
const DEFAULT_LUCKY_CONFIG = {
  receiver_percent: 5,
  gifts_for_bonus_min: 3,
  gifts_for_bonus_max: 4,
  bonus_multiplier_min: 1,
  bonus_multiplier_max: 500,
  bonus_chance_percent: 100,
  bonus_trigger_mode: "both",
};
const DEFAULT_LUCKY_PRO_CONFIG = {
  receiver_percent: 5,
  gifts_for_bonus_min: 2,
  gifts_for_bonus_max: 5,
  bonus_multiplier_min: 1,
  bonus_multiplier_max: 500,
  bonus_chance_percent: 100,
  bonus_trigger_mode: "both",
};
export default async function LuckyGiftsSettingsPage() {
  const [
    { data: luckyConfig },
    { data: luckyProConfig },
    { data: multiplierSvgas },
    { data: settingsRows },
  ] = await Promise.all([
    supabaseAdmin.from("lucky_gift_config").select("*").eq("id", 1).maybeSingle(),
    supabaseAdmin.from("lucky_pro_gift_config").select("*").eq("id", 1).maybeSingle(),
    supabaseAdmin
      .from("lucky_bonus_multiplier_svgas")
      .select("id, multiplier, label, svga_url, is_enabled, applies_to")
      .order("multiplier"),
    supabaseAdmin
      .from("system_settings")
      .select("key, value")
      .in("key", [
        "lucky_room_fanbi_svga_enabled",
        "lucky_room_multiplier_svga_enabled",
        "lucky_room_win_svga_enabled",
      ]),
  ]);
  const utcDayStart = new Date();
  utcDayStart.setUTCHours(0, 0, 0, 0);
  const luckyCapSince = new Date(
    Math.max(
      utcDayStart.getTime(),
      luckyConfig?.daily_cap_window_start
        ? new Date(luckyConfig.daily_cap_window_start).getTime()
        : 0,
    ),
  ).toISOString();
  const proCapSince = new Date(
    Math.max(
      utcDayStart.getTime(),
      luckyProConfig?.daily_cap_window_start
        ? new Date(luckyProConfig.daily_cap_window_start).getTime()
        : 0,
    ),
  ).toISOString();
  const [{ data: luckyLogs }, { data: proLogs }] = await Promise.all([
    supabaseAdmin
      .from("lucky_gift_bonus_logs")
      .select("bonus_coins")
      .gte("created_at", luckyCapSince),
    supabaseAdmin
      .from("lucky_pro_gift_bonus_logs")
      .select("bonus_coins")
      .gte("created_at", proCapSince),
  ]);
  const luckyTodayUsed = (luckyLogs ?? []).reduce(
    (sum, row) => sum + (Number(row.bonus_coins) || 0),
    0,
  );
  const luckyProTodayUsed = (proLogs ?? []).reduce(
    (sum, row) => sum + (Number(row.bonus_coins) || 0),
    0,
  );
  const settingMap = Object.fromEntries(
    (settingsRows ?? []).map((r) => [r.key, r.value?.toString() ?? ""]),
  );
  const parseEnabled = (raw: string | undefined, fallback: boolean) => {
    const v = raw?.trim().toLowerCase();
    if (v == null || v === "") return fallback;
    if (v === "false" || v === "0" || v === "off" || v === "no") return false;
    if (v === "true" || v === "1" || v === "on" || v === "yes") return true;
    return fallback;
  };
  const legacy = settingMap["lucky_room_win_svga_enabled"];
  const fanbiEnabled = parseEnabled(
    settingMap["lucky_room_fanbi_svga_enabled"],
    parseEnabled(legacy, true),
  );
  const multiplierEnabled = parseEnabled(
    settingMap["lucky_room_multiplier_svga_enabled"],
    parseEnabled(legacy, true),
  );
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-500">
          <Sparkles size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Lucky & Lucky Pro Gifts</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Configure bonus rules for both Lucky and Lucky Pro gift categories. Receiver gets
            diamond %; coin bonus goes to the sender.
          </p>
        </div>
      </header>

      <div className="space-y-8">
        <LuckyRoomWinSvgaToggle
          initialFanbiEnabled={fanbiEnabled}
          initialMultiplierEnabled={multiplierEnabled}
        />
        <LuckyDailyCapResetPanel
          luckyWindowStart={luckyConfig?.daily_cap_window_start ?? null}
          luckyProWindowStart={luckyProConfig?.daily_cap_window_start ?? null}
          luckyTodayUsed={luckyTodayUsed}
          luckyProTodayUsed={luckyProTodayUsed}
          luckyDailyCap={
            luckyConfig?.max_daily_bonus_per_sender != null
              ? Number(luckyConfig.max_daily_bonus_per_sender)
              : null
          }
          luckyProDailyCap={
            luckyProConfig?.max_daily_bonus_per_sender != null
              ? Number(luckyProConfig.max_daily_bonus_per_sender)
              : null
          }
        />
        <LuckyGiftConfigForm variant="lucky" config={luckyConfig ?? DEFAULT_LUCKY_CONFIG} />
        <LuckyGiftConfigForm
          variant="lucky_pro"
          config={luckyProConfig ?? DEFAULT_LUCKY_PRO_CONFIG}
        />
        <LuckyBonusMultiplierSvgasPanel
          rows={(multiplierSvgas ?? []) as LuckyBonusMultiplierSvgaRow[]}
        />
      </div>
    </div>
  );
}
