"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  createCpPartyEvent,
  createGameStarPartyEvent,
  createSkHostPartyEvent,
  createWebPartyEvent,
  createWeeklyStarPartyEvent,
  deletePartyEvent,
  updatePartyEvent,
  uploadPartyEventBanner,
  uploadCpEventRewardImage,
  settlePartyEventRewards,
  type GameConfigPickerItem,
  type GiftPickerItem,
  type PartyEventKind,
  type PartyRewardShopItem,
} from "@/app/settings/party-events/actions";
import {
  Gamepad2,
  Heart,
  Globe,
  Loader2,
  PartyPopper,
  Plus,
  Star,
  Trash2,
  Upload,
} from "lucide-react";
type EventRow = Record<string, unknown>;
type RewardPayoutType = "display" | "coins" | "shop_item";
type RewardItem = {
  label: string;
  image_url: string;
  reward_type: RewardPayoutType;
  coin_amount: number;
  shop_item_id: string;
  duration_days: number;
};
type RewardTier = {
  label: string;
  items: RewardItem[];
};
function emptyRewardItem(): RewardItem {
  return {
    label: "",
    image_url: "",
    reward_type: "display",
    coin_amount: 0,
    shop_item_id: "",
    duration_days: 0,
  };
}
type RewardSlots = {
  rank_1: RewardTier;
  rank_2: RewardTier;
  rank_3: RewardTier;
  rank_4_10: RewardTier;
};
function emptyRewardSlots(): RewardSlots {
  return {
    rank_1: { label: "Top 1", items: [emptyRewardItem()] },
    rank_2: { label: "Top 2", items: [emptyRewardItem()] },
    rank_3: { label: "Top 3", items: [emptyRewardItem()] },
    rank_4_10: {
      label: "Top 4 ~ 10",
      items: [emptyRewardItem(), emptyRewardItem()],
    },
  };
}
function parseRewardType(raw: unknown): RewardPayoutType {
  const v = String(raw ?? "").trim();
  if (v === "coins" || v === "shop_item") return v;
  return "display";
}
function parseRewardItem(raw: unknown): RewardItem {
  const o = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  return {
    label: String(o.label ?? ""),
    image_url: String(o.image_url ?? ""),
    reward_type: parseRewardType(o.reward_type),
    coin_amount: Number(o.coin_amount ?? 0) || 0,
    shop_item_id: String(o.shop_item_id ?? ""),
    duration_days: Number(o.duration_days ?? 0) || 0,
  };
}
function parseTier(raw: unknown, fallbackLabel: string): RewardTier {
  if (!raw || typeof raw !== "object") {
    return { label: fallbackLabel, items: [emptyRewardItem()] };
  }
  const m = raw as Record<string, unknown>;
  const label = String(m.label ?? fallbackLabel) || fallbackLabel;
  if (Array.isArray(m.items) && m.items.length > 0) {
    return { label, items: m.items.map(parseRewardItem) };
  }
  return { label, items: [parseRewardItem(m)] };
}
function parseRewardSlots(config: Record<string, unknown>): RewardSlots {
  const raw = config.reward_slots;
  if (!raw || typeof raw !== "object") return emptyRewardSlots();
  const r = raw as Record<string, unknown>;
  return {
    rank_1: parseTier(r.rank_1, "Top 1"),
    rank_2: parseTier(r.rank_2, "Top 2"),
    rank_3: parseTier(r.rank_3, "Top 3"),
    rank_4_10: parseTier(r.rank_4_10, "Top 4 ~ 10"),
  };
}
function parseGiftIds(
  config: Record<string, unknown>,
  key: "cp_gift_ids" | "weekly_star_gift_ids" = "cp_gift_ids",
): string[] {
  const raw = config[key];
  if (!Array.isArray(raw)) return [];
  return raw.map((x) => String(x)).filter(Boolean);
}
type WeeklyStarGiftSlot = {
  gift_id: string;
  points: number;
};
function parseWeeklyStarGifts(config: Record<string, unknown>): WeeklyStarGiftSlot[] {
  const raw = config.weekly_star_gifts;
  if (Array.isArray(raw) && raw.length > 0) {
    return raw
      .map((item) => {
        const o = item && typeof item === "object" ? (item as Record<string, unknown>) : {};
        return {
          gift_id: String(o.gift_id ?? o.id ?? ""),
          points: Number(o.points ?? 0) || 0,
        };
      })
      .filter((g) => g.gift_id)
      .slice(0, 4);
  }
  return parseGiftIds(config, "weekly_star_gift_ids")
    .slice(0, 4)
    .map((id) => ({ gift_id: id, points: 0 }));
}
function parseGameStarGameIds(config: Record<string, unknown>): string[] {
  const raw = config.game_star_game_ids;
  if (!Array.isArray(raw)) return [];
  return raw
    .map((x) => String(x))
    .filter(Boolean)
    .slice(0, 6);
}
function eventKind(row: EventRow): PartyEventKind {
  const kind = row.event_kind as string | undefined;
  if (
    kind === "cp_native" ||
    kind === "webview" ||
    kind === "weekly_star_native" ||
    kind === "game_star_native" ||
    kind === "sk_host_native"
  ) {
    return kind;
  }
  const legacy = row.screen_template as string | undefined;
  if (legacy === "cp_romance" || legacy === "cp_event") return "cp_native";
  if (legacy === "weekly_star") return "weekly_star_native";
  if (legacy === "game_star") return "game_star_native";
  if (legacy === "sk_host" || legacy === "sk_host_party" || legacy === "sk_party") {
    return "sk_host_native";
  }
  return "webview";
}
interface PartyEventsManagerProps {
  events: EventRow[];
  giftItems: GiftPickerItem[];
  gameConfigs: GameConfigPickerItem[];
  shopItems?: PartyRewardShopItem[];
}
export function PartyEventsManager({
  events,
  giftItems,
  gameConfigs,
  shopItems = [],
}: PartyEventsManagerProps) {
  const router = useRouter();
  const [creatingCp, setCreatingCp] = useState(false);
  const [creatingWeb, setCreatingWeb] = useState(false);
  const [creatingWs, setCreatingWs] = useState(false);
  const [creatingGs, setCreatingGs] = useState(false);
  const [creatingSk, setCreatingSk] = useState(false);
  const [uploadingId, setUploadingId] = useState<string | null>(null);
  const [cpTitle, setCpTitle] = useState("");
  const [webTitle, setWebTitle] = useState("");
  const [webUrl, setWebUrl] = useState("");
  const [wsTitle, setWsTitle] = useState("");
  const [gsTitle, setGsTitle] = useState("");
  const [skTitle, setSkTitle] = useState("");
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  async function handleCreateCp(e: React.FormEvent) {
    e.preventDefault();
    if (!cpTitle.trim()) return;
    setCreatingCp(true);
    const res = await createCpPartyEvent({ title: cpTitle.trim() });
    setCreatingCp(false);
    if (res.success) {
      setCpTitle("");
      router.refresh();
    } else {
      alert(res.error ?? "Failed to create CP event");
    }
  }
  async function handleCreateWeb(e: React.FormEvent) {
    e.preventDefault();
    if (!webTitle.trim() || !webUrl.trim()) return;
    setCreatingWeb(true);
    const res = await createWebPartyEvent({
      title: webTitle.trim(),
      web_url: webUrl.trim(),
    });
    setCreatingWeb(false);
    if (res.success) {
      setWebTitle("");
      setWebUrl("");
      router.refresh();
    } else {
      alert(res.error ?? "Failed to create web event");
    }
  }
  async function handleCreateWs(e: React.FormEvent) {
    e.preventDefault();
    if (!wsTitle.trim()) return;
    setCreatingWs(true);
    const res = await createWeeklyStarPartyEvent({ title: wsTitle.trim() });
    setCreatingWs(false);
    if (res.success) {
      setWsTitle("");
      router.refresh();
    } else {
      alert(res.error ?? "Failed to create Weekly Star event");
    }
  }
  async function handleCreateGs(e: React.FormEvent) {
    e.preventDefault();
    if (!gsTitle.trim()) return;
    setCreatingGs(true);
    const res = await createGameStarPartyEvent({ title: gsTitle.trim() });
    setCreatingGs(false);
    if (res.success) {
      setGsTitle("");
      router.refresh();
    } else {
      alert(res.error ?? "Failed to create Game Star event");
    }
  }
  async function handleCreateSk(e: React.FormEvent) {
    e.preventDefault();
    if (!skTitle.trim()) return;
    setCreatingSk(true);
    const res = await createSkHostPartyEvent({ title: skTitle.trim() });
    setCreatingSk(false);
    if (res.success) {
      setSkTitle("");
      router.refresh();
    } else {
      alert(res.error ?? "Failed to create SK Host Party event");
    }
  }
  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>, eventId: string) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingId(eventId);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("eventId", eventId);
    const res = await uploadPartyEventBanner(formData);
    setUploadingId(null);
    if (res.success) router.refresh();
    else alert(res.error ?? "Upload failed");
    e.target.value = "";
  }
  async function saveField(id: string, patch: Record<string, unknown>) {
    const res = await updatePartyEvent(id, patch);
    if (!res.success) alert(res.error ?? "Save failed");
    else router.refresh();
  }
  async function saveConfig(
    id: string,
    config: Record<string, unknown>,
    patch: Record<string, unknown>,
  ) {
    const res = await updatePartyEvent(id, {
      action_config: { ...config, ...patch },
    });
    if (!res.success) alert(res.error ?? "Save failed");
    else router.refresh();
  }
  async function handleDelete(id: string, title: string) {
    if (!confirm(`Delete event "${title}"?`)) return;
    const res = await deletePartyEvent(id);
    if (res.success) router.refresh();
    else alert(res.error ?? "Delete failed");
  }
  return (
    <div className="space-y-8">
      <section className="glass-card p-8 space-y-4">
        <h2 className="text-xl font-bold flex items-center gap-2">
          <Heart size={20} className="text-pink-400" /> Add CP Event
        </h2>
        <p className="text-white/50 text-sm">
          Opens the fixed native CP screen in the app. Upload banner after creating.
        </p>
        <form onSubmit={handleCreateCp} className="flex flex-wrap gap-4 items-end">
          <label className="flex flex-col gap-1 min-w-[200px] flex-1">
            <span className="text-xs text-white/50 uppercase tracking-wider">Title</span>
            <input
              className="bg-black/40 border border-white/10 rounded-xl px-4 py-3"
              value={cpTitle}
              onChange={(e) => setCpTitle(e.target.value)}
              placeholder="CP Events"
            />
          </label>
          <button
            type="submit"
            disabled={creatingCp}
            className="px-6 py-3 rounded-xl bg-pink-500 text-white font-bold hover:bg-pink-400 disabled:opacity-50"
          >
            {creatingCp ? <Loader2 className="animate-spin" size={18} /> : "Create CP Event"}
          </button>
        </form>
      </section>

      <section className="glass-card p-8 space-y-4">
        <h2 className="text-xl font-bold flex items-center gap-2">
          <Star size={20} className="text-amber-300" /> Add Weekly Star Event
        </h2>
        <p className="text-white/50 text-sm">
          Opens the native Weekly Star screen. Tag gifts + rewards after creating; upload a banner
          for the Party Events card.
        </p>
        <form onSubmit={handleCreateWs} className="flex flex-wrap gap-4 items-end">
          <label className="flex flex-col gap-1 min-w-[200px] flex-1">
            <span className="text-xs text-white/50 uppercase tracking-wider">Title</span>
            <input
              className="bg-black/40 border border-white/10 rounded-xl px-4 py-3"
              value={wsTitle}
              onChange={(e) => setWsTitle(e.target.value)}
              placeholder="Weekly Star"
            />
          </label>
          <button
            type="submit"
            disabled={creatingWs}
            className="px-6 py-3 rounded-xl bg-amber-500 text-black font-bold hover:bg-amber-400 disabled:opacity-50"
          >
            {creatingWs ? <Loader2 className="animate-spin" size={18} /> : "Create Weekly Star"}
          </button>
        </form>
      </section>

      <section className="glass-card p-8 space-y-4">
        <h2 className="text-xl font-bold flex items-center gap-2">
          <Gamepad2 size={20} className="text-red-400" /> Add Game Star Event
        </h2>
        <p className="text-white/50 text-sm">
          Opens the native Game Star screen. Tag display games + rewards after creating — only wins
          from selected games count toward ranking.
        </p>
        <form onSubmit={handleCreateGs} className="flex flex-wrap gap-4 items-end">
          <label className="flex flex-col gap-1 min-w-[200px] flex-1">
            <span className="text-xs text-white/50 uppercase tracking-wider">Title</span>
            <input
              className="bg-black/40 border border-white/10 rounded-xl px-4 py-3"
              value={gsTitle}
              onChange={(e) => setGsTitle(e.target.value)}
              placeholder="Game Star"
            />
          </label>
          <button
            type="submit"
            disabled={creatingGs}
            className="px-6 py-3 rounded-xl bg-red-500 text-white font-bold hover:bg-red-400 disabled:opacity-50"
          >
            {creatingGs ? <Loader2 className="animate-spin" size={18} /> : "Create Game Star"}
          </button>
        </form>
      </section>

      <section className="glass-card p-8 space-y-4">
        <h2 className="text-xl font-bold flex items-center gap-2">
          <PartyPopper size={20} className="text-blue-300" /> Add SK Host Party
        </h2>
        <p className="text-white/50 text-sm">
          Simple native Host Party screen with bundled banner/BG, countdown, and rules. No ranking
          setup required.
        </p>
        <form onSubmit={handleCreateSk} className="flex flex-wrap gap-4 items-end">
          <label className="flex flex-col gap-1 min-w-[200px] flex-1">
            <span className="text-xs text-white/50 uppercase tracking-wider">Title</span>
            <input
              className="bg-black/40 border border-white/10 rounded-xl px-4 py-3"
              value={skTitle}
              onChange={(e) => setSkTitle(e.target.value)}
              placeholder="SK Host Party"
            />
          </label>
          <button
            type="submit"
            disabled={creatingSk}
            className="px-6 py-3 rounded-xl bg-blue-500 text-white font-bold hover:bg-blue-400 disabled:opacity-50"
          >
            {creatingSk ? <Loader2 className="animate-spin" size={18} /> : "Create SK Host Party"}
          </button>
        </form>
      </section>

      <section className="glass-card p-8 space-y-4">
        <h2 className="text-xl font-bold flex items-center gap-2">
          <Globe size={20} className="text-sky-400" /> Add Web Event
        </h2>
        <p className="text-white/50 text-sm">
          Opens in-app WebView. Banner + URL required for users to see content.
        </p>
        <form onSubmit={handleCreateWeb} className="flex flex-wrap gap-4 items-end">
          <label className="flex flex-col gap-1 min-w-[160px] flex-1">
            <span className="text-xs text-white/50 uppercase tracking-wider">Title</span>
            <input
              className="bg-black/40 border border-white/10 rounded-xl px-4 py-3"
              value={webTitle}
              onChange={(e) => setWebTitle(e.target.value)}
              placeholder="Summer Carnival"
            />
          </label>
          <label className="flex flex-col gap-1 min-w-[240px] flex-[2]">
            <span className="text-xs text-white/50 uppercase tracking-wider">Web URL</span>
            <input
              className="bg-black/40 border border-white/10 rounded-xl px-4 py-3"
              value={webUrl}
              onChange={(e) => setWebUrl(e.target.value)}
              placeholder="https://..."
              type="url"
            />
          </label>
          <button
            type="submit"
            disabled={creatingWeb}
            className="px-6 py-3 rounded-xl bg-sky-500 text-white font-bold hover:bg-sky-400 disabled:opacity-50"
          >
            {creatingWeb ? <Loader2 className="animate-spin" size={18} /> : "Create Web Event"}
          </button>
        </form>
      </section>

      {events.length === 0 ? (
        <p className="text-white/40 text-center py-12">
          No events yet. Create a CP, Weekly Star, Game Star, SK Host Party, or Web event above,
          then upload a banner if needed.
        </p>
      ) : (
        events.map((ev) => {
          const id = String(ev.id);
          const kind = eventKind(ev);
          const isCp = kind === "cp_native";
          const isWeeklyStar = kind === "weekly_star_native";
          const isGameStar = kind === "game_star_native";
          const isSkHost = kind === "sk_host_native";
          const isWebview = kind === "webview";
          const config =
            ev.action_config && typeof ev.action_config === "object"
              ? (ev.action_config as Record<string, unknown>)
              : {};
          const bannerUrl = (ev.banner_url as string) ?? "";
          return (
            <article key={id} className="glass-card p-6 space-y-5">
              <div className="flex flex-wrap gap-4 justify-between items-start">
                <div className="flex gap-4 items-start">
                  <div className="w-40 h-24 rounded-xl overflow-hidden bg-black/40 border border-white/10 shrink-0">
                    {bannerUrl ? (
                      <img src={bannerUrl} alt="" className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-white/20 text-xs">
                        No banner
                      </div>
                    )}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      {isCp ? (
                        <span className="text-xs font-bold uppercase tracking-wider text-pink-400 bg-pink-500/10 px-2 py-1 rounded">
                          CP Native
                        </span>
                      ) : isWeeklyStar ? (
                        <span className="text-xs font-bold uppercase tracking-wider text-amber-300 bg-amber-500/10 px-2 py-1 rounded">
                          Weekly Star
                        </span>
                      ) : isGameStar ? (
                        <span className="text-xs font-bold uppercase tracking-wider text-red-400 bg-red-500/10 px-2 py-1 rounded">
                          Game Star
                        </span>
                      ) : isSkHost ? (
                        <span className="text-xs font-bold uppercase tracking-wider text-blue-300 bg-blue-500/10 px-2 py-1 rounded">
                          SK Host Party
                        </span>
                      ) : (
                        <span className="text-xs font-bold uppercase tracking-wider text-sky-400 bg-sky-500/10 px-2 py-1 rounded">
                          WebView
                        </span>
                      )}
                    </div>
                    <p className="font-bold text-lg mt-2">{String(ev.title ?? "")}</p>
                    <p className="text-white/40 text-xs font-mono mt-1">{id}</p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => handleDelete(id, String(ev.title))}
                  className="p-2 rounded-lg text-red-400 hover:bg-red-500/10"
                  title="Delete"
                >
                  <Trash2 size={18} />
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <Field
                  label="Title"
                  defaultValue={String(ev.title ?? "")}
                  onBlur={(v) => saveField(id, { title: v })}
                />
                <Field
                  label="Subtitle"
                  defaultValue={String(ev.subtitle ?? "")}
                  onBlur={(v) => saveField(id, { subtitle: v })}
                />
                {isCp ? (
                  <>
                    <TextAreaField
                      label="Rules"
                      defaultValue={String(config.rules ?? "")}
                      onBlur={(v) => saveConfig(id, config, { rules: v })}
                    />
                    <Field
                      label="CTA button label"
                      defaultValue={String(config.cta_label ?? "Open CP Nest")}
                      onBlur={(v) => saveConfig(id, config, { cta_label: v })}
                    />
                  </>
                ) : isWeeklyStar || isGameStar || isSkHost ? (
                  <TextAreaField
                    label={
                      isGameStar
                        ? "Rules (rules popup in app)"
                        : isSkHost
                          ? "Rules (shown on event screen)"
                          : "Rules (shown under This Week Gift)"
                    }
                    defaultValue={String(config.rules ?? "")}
                    onBlur={(v) => saveConfig(id, config, { rules: v })}
                  />
                ) : (
                  <>
                    <Field
                      label="Web URL"
                      defaultValue={String(config.web_url ?? "")}
                      onBlur={(v) => saveConfig(id, config, { web_url: v })}
                    />
                    <Field
                      label="In-app page title"
                      defaultValue={String(config.page_title ?? ev.title ?? "")}
                      onBlur={(v) => saveConfig(id, config, { page_title: v })}
                    />
                    {isWebview ? (
                      <TextAreaField
                        label="Rules (shown under Event Gift)"
                        defaultValue={String(config.rules ?? "")}
                        onBlur={(v) => saveConfig(id, config, { rules: v })}
                      />
                    ) : null}
                  </>
                )}
                <Field
                  label="Priority (higher first)"
                  type="number"
                  defaultValue={String(ev.priority ?? 0)}
                  onBlur={(v) => saveField(id, { priority: parseInt(v, 10) || 0 })}
                />
                <label className="flex items-center gap-2 pt-6">
                  <input
                    type="checkbox"
                    defaultChecked={ev.is_active !== false}
                    onChange={(e) => saveField(id, { is_active: e.target.checked })}
                  />
                  <span className="text-sm">Active (visible in app)</span>
                </label>
                <Field
                  label="Start (optional)"
                  defaultValue={ev.start_at ? String(ev.start_at).slice(0, 16) : ""}
                  onBlur={(v) =>
                    saveField(id, {
                      start_at: v ? new Date(v).toISOString() : null,
                    })
                  }
                />
                <Field
                  label="End (optional)"
                  defaultValue={ev.end_at ? String(ev.end_at).slice(0, 16) : ""}
                  onBlur={(v) =>
                    saveField(id, {
                      end_at: v ? new Date(v).toISOString() : null,
                    })
                  }
                />
              </div>

              {isCp && (
                <>
                  <CpGiftPicker
                    eventId={id}
                    config={config}
                    giftItems={giftItems}
                    selectedIds={parseGiftIds(config, "cp_gift_ids")}
                    title="CP Event Gifts"
                    hint="Only selected gifts count toward Rank / Gift Top for this event."
                    onSave={(ids) => saveConfig(id, config, { cp_gift_ids: ids })}
                  />
                  <CpRewardSlotsEditor
                    eventId={id}
                    config={config}
                    shopItems={shopItems}
                    initial={parseRewardSlots(config)}
                    maxByTier={{ rank_1: 4, rank_2: 4, rank_3: 4, rank_4_10: 2 }}
                    hint="Top 1–3 use the 4-slot frame. After event end, coins / shop items are sent automatically."
                    onSave={(slots) => saveConfig(id, config, { reward_slots: slots })}
                  />
                </>
              )}

              {(isWeeklyStar || isWebview) && (
                <>
                  <WeeklyStarGiftEditor
                    giftItems={giftItems}
                    initial={parseWeeklyStarGifts(config)}
                    onSave={(gifts) =>
                      saveConfig(id, config, {
                        weekly_star_gifts: gifts,
                        weekly_star_gift_ids: gifts.map((g) => g.gift_id),
                      })
                    }
                  />
                  <CpRewardSlotsEditor
                    eventId={id}
                    config={config}
                    shopItems={shopItems}
                    initial={parseRewardSlots(config)}
                    maxByTier={{ rank_1: 7, rank_2: 5, rank_3: 5, rank_4_10: 2 }}
                    hint="Top 1 → max 7. Top 2/3 → max 5. Top 4~10 → max 2. After end time, coins / medals / gifts are sent automatically."
                    onSave={(slots) => saveConfig(id, config, { reward_slots: slots })}
                  />
                </>
              )}

              {isGameStar && (
                <>
                  <GameStarGamePicker
                    gameConfigs={gameConfigs}
                    selectedIds={parseGameStarGameIds(config)}
                    onSave={(ids) => saveConfig(id, config, { game_star_game_ids: ids })}
                  />
                  <CpRewardSlotsEditor
                    eventId={id}
                    config={config}
                    shopItems={shopItems}
                    initial={parseRewardSlots(config)}
                    maxByTier={{ rank_1: 5, rank_2: 5, rank_3: 5, rank_4_10: 2 }}
                    hint="Top 1/2/3 → max 5. Top 4~10 → max 2. After event end, payout is automatic."
                    onSave={(slots) => saveConfig(id, config, { reward_slots: slots })}
                  />
                </>
              )}

              <div>
                <input
                  ref={(el) => {
                    fileRefs.current[id] = el;
                  }}
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  className="hidden"
                  onChange={(e) => handleUpload(e, id)}
                />
                <button
                  type="button"
                  disabled={uploadingId === id}
                  onClick={() => fileRefs.current[id]?.click()}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border border-white/20 hover:bg-white/5 text-sm font-semibold"
                >
                  {uploadingId === id ? (
                    <Loader2 className="animate-spin" size={16} />
                  ) : (
                    <Upload size={16} />
                  )}
                  Upload banner
                </button>
                <p className="text-white/40 text-xs mt-2">
                  Shown on Home → Party → Events tab (~16:7, e.g. 1280×560).
                </p>
              </div>
            </article>
          );
        })
      )}
    </div>
  );
}
function GameStarGamePicker({
  gameConfigs,
  selectedIds,
  onSave,
}: {
  gameConfigs: GameConfigPickerItem[];
  selectedIds: string[];
  onSave: (ids: string[]) => void;
}) {
  const [selected, setSelected] = useState<string[]>(() => selectedIds.slice(0, 6));
  const [saving, setSaving] = useState(false);
  function toggle(id: string) {
    setSelected((prev) => {
      if (prev.includes(id)) return prev.filter((x) => x !== id);
      if (prev.length >= 6) {
        alert("Select up to 6 games for the hero row.");
        return prev;
      }
      return [...prev, id];
    });
  }
  async function handleSave() {
    setSaving(true);
    await onSave(selected.slice(0, 6));
    setSaving(false);
  }
  return (
    <div className="rounded-2xl border border-red-500/20 bg-red-500/5 p-4 space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="font-bold text-red-300">Display games ({selected.length}/6)</h3>
          <p className="text-white/40 text-xs mt-1">
            These games show on the Game Star screen AND only wins from these games count toward
            ranking points (max 6).
          </p>
        </div>
        <button
          type="button"
          disabled={saving}
          onClick={handleSave}
          className="px-4 py-2 rounded-xl bg-red-500 text-white text-sm font-bold hover:bg-red-400 disabled:opacity-50"
        >
          {saving ? <Loader2 className="animate-spin" size={16} /> : "Save games"}
        </button>
      </div>

      {gameConfigs.length === 0 ? (
        <p className="text-white/40 text-sm">No active game_configs found.</p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2 max-h-64 overflow-y-auto">
          {gameConfigs.map((g) => {
            const on = selected.includes(g.id);
            return (
              <button
                key={g.id}
                type="button"
                onClick={() => toggle(g.id)}
                className={`flex items-center gap-2 rounded-xl border px-3 py-2 text-left text-sm transition ${
                  on
                    ? "border-red-400 bg-red-500/20 text-white"
                    : "border-white/10 bg-black/30 text-white/70 hover:bg-white/5"
                }`}
              >
                {g.icon_url ? (
                  <img
                    src={g.icon_url}
                    alt=""
                    className="w-8 h-8 rounded object-cover bg-black/40"
                  />
                ) : (
                  <div className="w-8 h-8 rounded bg-white/10" />
                )}
                <span className="truncate font-semibold">{g.name}</span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
function WeeklyStarGiftEditor({
  giftItems,
  initial,
  onSave,
}: {
  giftItems: GiftPickerItem[];
  initial: WeeklyStarGiftSlot[];
  onSave: (gifts: WeeklyStarGiftSlot[]) => void;
}) {
  const [slots, setSlots] = useState<WeeklyStarGiftSlot[]>(() => {
    const base = [...initial];
    while (base.length < 4) base.push({ gift_id: "", points: 0 });
    return base.slice(0, 4);
  });
  const [saving, setSaving] = useState(false);
  function setSlot(index: number, patch: Partial<WeeklyStarGiftSlot>) {
    setSlots((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], ...patch };
      return next;
    });
  }
  async function handleSave() {
    const cleaned = slots
      .filter((s) => s.gift_id)
      .map((s) => ({
        gift_id: s.gift_id,
        points: Math.max(0, Number(s.points) || 0),
      }));
    if (cleaned.length === 0) {
      alert("Select at least one gift (max 4).");
      return;
    }
    if (cleaned.some((s) => s.points <= 0)) {
      alert("Set points > 0 for each selected gift.");
      return;
    }
    setSaving(true);
    await onSave(cleaned);
    setSaving(false);
  }
  return (
    <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 p-4 space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="font-bold text-amber-300">This Week Gifts (max 4)</h3>
          <p className="text-white/40 text-xs mt-1">
            These 4 gifts show on the rules frame. When a user receives one, they get the points you
            set below.
          </p>
        </div>
        <button
          type="button"
          disabled={saving}
          onClick={handleSave}
          className="px-4 py-2 rounded-xl bg-amber-500 text-black text-sm font-bold hover:bg-amber-400 disabled:opacity-50"
        >
          {saving ? <Loader2 className="animate-spin" size={16} /> : "Save gifts"}
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {slots.map((slot, idx) => {
          const selected = giftItems.find((g) => g.id === slot.gift_id);
          return (
            <div key={idx} className="rounded-xl border border-white/10 bg-black/30 p-3 space-y-2">
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-bold text-amber-200/80">Slot {idx + 1}</span>
                {selected?.image_url ? (
                  <img
                    src={selected.image_url}
                    alt=""
                    className="w-9 h-9 object-contain rounded bg-black/40"
                  />
                ) : (
                  <div className="w-9 h-9 rounded bg-white/5" />
                )}
              </div>
              <select
                className="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-sm"
                value={slot.gift_id}
                onChange={(e) => {
                  const id = e.target.value;
                  const g = giftItems.find((x) => x.id === id);
                  setSlot(idx, {
                    gift_id: id,
                    points: slot.points > 0 ? slot.points : Number(g?.price_coins ?? 0) || 0,
                  });
                }}
              >
                <option value="">— Select gift —</option>
                {giftItems.map((g) => (
                  <option key={g.id} value={g.id}>
                    {g.name} ({g.price_coins} coins)
                  </option>
                ))}
              </select>
              <label className="flex flex-col gap-1">
                <span className="text-[10px] uppercase text-white/40">
                  Event points (when received)
                </span>
                <input
                  type="number"
                  min={0}
                  className="bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-sm"
                  value={slot.points || ""}
                  placeholder={selected ? String(selected.price_coins) : "e.g. 500"}
                  onChange={(e) => setSlot(idx, { points: parseInt(e.target.value, 10) || 0 })}
                />
              </label>
            </div>
          );
        })}
      </div>
    </div>
  );
}
function CpGiftPicker({
  giftItems,
  selectedIds,
  onSave,
  title = "CP Event Gifts",
  hint = "Only selected gifts count toward Rank / Gift Top for this event.",
  accent = "pink",
}: {
  eventId: string;
  config: Record<string, unknown>;
  giftItems: GiftPickerItem[];
  selectedIds: string[];
  onSave: (ids: string[]) => void;
  title?: string;
  hint?: string;
  accent?: "pink" | "amber";
}) {
  const [selected, setSelected] = useState<Set<string>>(() => new Set(selectedIds));
  const [saving, setSaving] = useState(false);
  const border =
    accent === "amber" ? "border-amber-500/20 bg-amber-500/5" : "border-pink-500/20 bg-pink-500/5";
  const titleColor = accent === "amber" ? "text-amber-300" : "text-pink-300";
  const btn =
    accent === "amber"
      ? "bg-amber-500 text-black hover:bg-amber-400"
      : "bg-pink-500 text-white hover:bg-pink-400";
  const checkedBorder =
    accent === "amber" ? "border-amber-400 bg-amber-500/20" : "border-pink-400 bg-pink-500/20";
  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }
  async function handleSave() {
    setSaving(true);
    await onSave(Array.from(selected));
    setSaving(false);
  }
  return (
    <div className={`rounded-2xl border ${border} p-4 space-y-3`}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className={`font-bold ${titleColor}`}>{title}</h3>
          <p className="text-white/40 text-xs mt-1">{hint}</p>
        </div>
        <button
          type="button"
          disabled={saving}
          onClick={handleSave}
          className={`px-4 py-2 rounded-xl text-sm font-bold disabled:opacity-50 ${btn}`}
        >
          {saving ? <Loader2 className="animate-spin" size={16} /> : "Save gifts"}
        </button>
      </div>
      {giftItems.length === 0 ? (
        <p className="text-white/40 text-sm">
          No active gift shop items found. Mark items as gifts in Shop.
        </p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2 max-h-64 overflow-y-auto">
          {giftItems.map((g) => {
            const checked = selected.has(g.id);
            return (
              <label
                key={g.id}
                className={`flex items-center gap-2 p-2 rounded-xl border cursor-pointer ${checked ? checkedBorder : "border-white/10 bg-black/30"}`}
              >
                <input
                  type="checkbox"
                  checked={checked}
                  onChange={() => toggle(g.id)}
                  className="shrink-0"
                />
                {g.image_url ? (
                  <img src={g.image_url} alt="" className="w-8 h-8 object-contain rounded" />
                ) : (
                  <div className="w-8 h-8 rounded bg-white/10" />
                )}
                <div className="min-w-0">
                  <p className="text-xs font-semibold truncate">{g.name}</p>
                  <p className="text-[10px] text-white/40">{g.price_coins} coins</p>
                </div>
              </label>
            );
          })}
        </div>
      )}
    </div>
  );
}
function CpRewardSlotsEditor({
  eventId,
  initial,
  onSave,
  shopItems = [],
  maxByTier = { rank_1: 4, rank_2: 4, rank_3: 4, rank_4_10: 2 },
  hint = "Top 1–3 use the 4-slot frame. Top 4~10 uses the 2-slot frame (reward-2).",
}: {
  eventId: string;
  config: Record<string, unknown>;
  initial: RewardSlots;
  onSave: (slots: RewardSlots) => void;
  shopItems?: PartyRewardShopItem[];
  maxByTier?: Record<keyof RewardSlots, number>;
  hint?: string;
}) {
  const [slots, setSlots] = useState<RewardSlots>(initial);
  const [saving, setSaving] = useState(false);
  const [settling, setSettling] = useState(false);
  const [uploading, setUploading] = useState<string | null>(null);
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  function patchItem(tierKey: keyof RewardSlots, idx: number, partial: Partial<RewardItem>) {
    setSlots((s) => {
      const items = [...s[tierKey].items];
      items[idx] = { ...items[idx], ...partial };
      return { ...s, [tierKey]: { ...s[tierKey], items } };
    });
  }
  async function uploadFor(slotKey: string, file: File, applyUrl: (url: string) => void) {
    setUploading(slotKey);
    const fd = new FormData();
    fd.append("file", file);
    fd.append("eventId", eventId);
    fd.append("slotKey", slotKey);
    const res = await uploadCpEventRewardImage(fd);
    setUploading(null);
    if (res.success && res.url) applyUrl(res.url);
    else alert(res.error ?? "Upload failed");
  }
  async function handleSave() {
    setSaving(true);
    await onSave(slots);
    setSaving(false);
  }
  async function handleSettle() {
    if (
      !confirm(
        "Send Top 1–10 rewards now? Only works after the event end time. Already-sent items are skipped.",
      )
    ) {
      return;
    }
    setSettling(true);
    const res = await settlePartyEventRewards(eventId, false);
    setSettling(false);
    if (!res.success) {
      alert(res.error ?? "Settle failed");
      return;
    }
    const granted =
      res.result && typeof res.result === "object"
        ? (res.result as {
            granted?: number;
            already_settled?: boolean;
          })
        : {};
    if (granted.already_settled) {
      alert("Already settled. No extra payout.");
      return;
    }
    alert(`Settled. Granted ${Number(granted.granted ?? 0)} reward(s).`);
  }
  function TierEditor({ tierKey, title }: { tierKey: keyof RewardSlots; title: string }) {
    const tier = slots[tierKey];
    const maxItems = maxByTier[tierKey];
    return (
      <div className="rounded-xl border border-white/10 bg-black/30 p-3 space-y-3">
        <div className="flex items-center justify-between gap-2">
          <input
            className="flex-1 bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-sm font-bold"
            value={tier.label}
            onChange={(e) =>
              setSlots((s) => ({
                ...s,
                [tierKey]: { ...s[tierKey], label: e.target.value },
              }))
            }
            placeholder={title}
          />
          <button
            type="button"
            disabled={tier.items.length >= maxItems}
            onClick={() =>
              setSlots((s) => ({
                ...s,
                [tierKey]: {
                  ...s[tierKey],
                  items: [...s[tierKey].items, emptyRewardItem()],
                },
              }))
            }
            className="inline-flex items-center gap-1 px-3 py-2 rounded-lg border border-white/20 text-xs font-semibold disabled:opacity-40"
          >
            <Plus size={14} /> Add
          </button>
        </div>
        {tier.items.map((item, idx) => {
          const inputKey = `${eventId}-${tierKey}-${idx}`;
          const shop = shopItems.find((s) => s.id === item.shop_item_id);
          return (
            <div key={idx} className="space-y-2 border-t border-white/5 pt-3">
              <div className="flex flex-wrap items-center gap-2">
                <input
                  className="flex-1 min-w-[120px] bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-sm"
                  value={item.label}
                  onChange={(e) => patchItem(tierKey, idx, { label: e.target.value })}
                  placeholder="Reward label"
                />
                {item.image_url || shop?.image_url ? (
                  <img
                    src={item.image_url || shop?.image_url}
                    alt=""
                    className="w-10 h-10 object-contain rounded bg-black/40"
                  />
                ) : (
                  <div className="w-10 h-10 rounded bg-white/5" />
                )}
                <input
                  ref={(el) => {
                    fileRefs.current[inputKey] = el;
                  }}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (!f) return;
                    void uploadFor(`${tierKey}_${idx}`, f, (url) =>
                      patchItem(tierKey, idx, { image_url: url }),
                    );
                    e.target.value = "";
                  }}
                />
                <button
                  type="button"
                  disabled={uploading === `${tierKey}_${idx}`}
                  onClick={() => fileRefs.current[inputKey]?.click()}
                  className="px-3 py-1.5 rounded-lg border border-white/20 text-xs font-semibold"
                >
                  {uploading === `${tierKey}_${idx}` ? (
                    <Loader2 className="animate-spin" size={14} />
                  ) : (
                    "Upload"
                  )}
                </button>
                {tier.items.length > 1 && (
                  <button
                    type="button"
                    onClick={() =>
                      setSlots((s) => ({
                        ...s,
                        [tierKey]: {
                          ...s[tierKey],
                          items: s[tierKey].items.filter((_, i) => i !== idx),
                        },
                      }))
                    }
                    className="p-1.5 text-red-400"
                  >
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                <label className="text-[11px] text-white/50">
                  Payout
                  <select
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-lg px-2 py-2 text-sm text-white"
                    value={item.reward_type}
                    onChange={(e) =>
                      patchItem(tierKey, idx, {
                        reward_type: e.target.value as RewardPayoutType,
                      })
                    }
                  >
                    <option value="display">Display only</option>
                    <option value="coins">Coins</option>
                    <option value="shop_item">Shop / medal / gift</option>
                  </select>
                </label>
                {item.reward_type === "coins" ? (
                  <label className="text-[11px] text-white/50 sm:col-span-2">
                    Coin amount
                    <input
                      type="number"
                      min={1}
                      className="mt-1 w-full bg-black/40 border border-white/10 rounded-lg px-2 py-2 text-sm"
                      value={item.coin_amount || ""}
                      onChange={(e) =>
                        patchItem(tierKey, idx, {
                          coin_amount: Number(e.target.value) || 0,
                        })
                      }
                    />
                  </label>
                ) : null}
                {item.reward_type === "shop_item" ? (
                  <>
                    <label className="text-[11px] text-white/50 sm:col-span-2">
                      Shop item
                      <select
                        className="mt-1 w-full bg-black/40 border border-white/10 rounded-lg px-2 py-2 text-sm text-white"
                        value={item.shop_item_id}
                        onChange={(e) => {
                          const next = e.target.value;
                          const found = shopItems.find((s) => s.id === next);
                          patchItem(tierKey, idx, {
                            shop_item_id: next,
                            image_url: item.image_url || found?.image_url || "",
                            label: item.label || found?.name || "",
                          });
                        }}
                      >
                        <option value="">Select medal / frame / gift…</option>
                        {shopItems.map((s) => (
                          <option key={s.id} value={s.id}>
                            {s.name} ({s.price_coins}c)
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="text-[11px] text-white/50 sm:col-span-3">
                      Duration days (0 = shop default / permanent)
                      <input
                        type="number"
                        min={0}
                        className="mt-1 w-full bg-black/40 border border-white/10 rounded-lg px-2 py-2 text-sm"
                        value={item.duration_days || 0}
                        onChange={(e) =>
                          patchItem(tierKey, idx, {
                            duration_days: Number(e.target.value) || 0,
                          })
                        }
                      />
                    </label>
                  </>
                ) : null}
              </div>
            </div>
          );
        })}
      </div>
    );
  }
  return (
    <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 p-4 space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="font-bold text-amber-300">Reward Slots</h3>
          <p className="text-white/40 text-xs mt-1">{hint}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            disabled={settling}
            onClick={handleSettle}
            className="px-4 py-2 rounded-xl border border-white/20 text-sm font-bold hover:bg-white/5 disabled:opacity-50"
          >
            {settling ? <Loader2 className="animate-spin" size={16} /> : "Settle now"}
          </button>
          <button
            type="button"
            disabled={saving}
            onClick={handleSave}
            className="px-4 py-2 rounded-xl bg-amber-500 text-black text-sm font-bold hover:bg-amber-400 disabled:opacity-50"
          >
            {saving ? <Loader2 className="animate-spin" size={16} /> : "Save rewards"}
          </button>
        </div>
      </div>

      <TierEditor tierKey="rank_1" title="Top 1" />
      <TierEditor tierKey="rank_2" title="Top 2" />
      <TierEditor tierKey="rank_3" title="Top 3" />
      <TierEditor tierKey="rank_4_10" title="Top 4 ~ 10" />
    </div>
  );
}
function Field({
  label,
  defaultValue,
  onBlur,
  type = "text",
}: {
  label: string;
  defaultValue: string;
  onBlur: (value: string) => void;
  type?: string;
}) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-xs text-white/50 uppercase">{label}</span>
      <input
        type={type}
        className="bg-black/40 border border-white/10 rounded-xl px-3 py-2"
        defaultValue={defaultValue}
        onBlur={(e) => onBlur(e.target.value)}
      />
    </label>
  );
}
function TextAreaField({
  label,
  defaultValue,
  onBlur,
}: {
  label: string;
  defaultValue: string;
  onBlur: (value: string) => void;
}) {
  return (
    <label className="flex flex-col gap-1 md:col-span-2">
      <span className="text-xs text-white/50 uppercase">{label}</span>
      <textarea
        className="bg-black/40 border border-white/10 rounded-xl px-3 py-2 min-h-[72px]"
        defaultValue={defaultValue}
        onBlur={(e) => onBlur(e.target.value)}
      />
    </label>
  );
}
