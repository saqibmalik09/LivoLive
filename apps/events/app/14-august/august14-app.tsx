"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import {
  fetchEvent,
  fetchGifts,
  fetchLeader,
  fetchMyRank,
  fetchRankings,
  formatScore,
  readEventIdFromSearch,
  refreshWindowRankings,
  rewardSlotsFromConfig,
  rulesFromConfig,
  type EventRow,
  type GiftItem,
  type RankRow,
  type RewardItem,
  type RewardSlots,
} from "@/lib/august14";
import { applyWebViewSessionFromHost } from "@/lib/webview-auth";

const A = {
  bg: "/14-august/weekly-star-bg.webp",
  hero: "/14-august/weekly-star-hero.webp",
  timer: "/14-august/timer-box.webp",
  rules: "/14-august/rules.webp",
  top3: "/14-august/top-3.webp",
  topFrame: "/14-august/top-frame.webp",
  button: "/14-august/button.webp",
  focus: "/14-august/focus-button.webp",
  reward2: "/14-august/reward-2.webp",
  reward5: "/14-august/reward-5.webp",
  reward7: "/14-august/reward-7.webp",
};

type Tab = "ranking" | "reward";

export function August14App() {
  const search = useSearchParams();
  const eventId =
    search.get("event_id")?.trim() ||
    readEventIdFromSearch(
      typeof window === "undefined" ? "" : window.location.search,
    );

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [event, setEvent] = useState<EventRow | null>(null);
  const [gifts, setGifts] = useState<GiftItem[]>([]);
  const [rankings, setRankings] = useState<RankRow[]>([]);
  const [leader, setLeader] = useState<RankRow | null>(null);
  const [me, setMe] = useState<RankRow | null>(null);
  const [tab, setTab] = useState<Tab>("ranking");

  const load = useCallback(async () => {
    if (!eventId) {
      setError("Missing event_id. Open this page from the SK Live app.");
      setLoading(false);
      return;
    }
    try {
      await applyWebViewSessionFromHost();
      const row = await fetchEvent(eventId);
      if (!row) {
        setError("Event not found.");
        setLoading(false);
        return;
      }
      setEvent(row);
      const [giftList] = await Promise.all([
        fetchGifts(row.action_config),
        refreshWindowRankings(eventId).catch(() => undefined),
      ]);
      setGifts(giftList);
      const [ranks, lead, mine] = await Promise.all([
        fetchRankings(eventId),
        fetchLeader(eventId),
        fetchMyRank(eventId),
      ]);
      setRankings(ranks);
      setLeader(lead ?? ranks[0] ?? null);
      setMe(mine);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load event.");
    } finally {
      setLoading(false);
    }
  }, [eventId]);

  useEffect(() => {
    void load();
    const id = window.setInterval(() => void load(), 30_000);
    return () => window.clearInterval(id);
  }, [load]);

  const rules = useMemo(
    () => (event ? rulesFromConfig(event.action_config) : ""),
    [event],
  );
  const slots = useMemo(
    () =>
      event
        ? rewardSlotsFromConfig(event.action_config)
        : rewardSlotsFromConfig({}),
    [event],
  );

  if (loading) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-[#0A0618] text-white">
        Loading…
      </div>
    );
  }

  if (error || !event) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-[#0A0618] px-8 text-center text-white/70">
        {error ?? "Event not found."}
      </div>
    );
  }

  return (
    <div className="relative min-h-dvh bg-[#0A0618] text-white">
      <div
        className="pointer-events-none absolute inset-x-0 bottom-0 top-[28%] bg-cover bg-top"
        style={{
          backgroundImage: `linear-gradient(to bottom, transparent, #0A0618 12%, #0A0618 72%, transparent), url(${A.bg})`,
        }}
      />
      <div className="relative flex min-h-dvh flex-col">
        <div className="flex-1 overflow-y-auto pb-24">
          <Header title={event.title} endAt={event.end_at} winner={leader} />
          <GiftsRules gifts={gifts} rules={rules} />
          <Tabs tab={tab} onChange={setTab} />
          {tab === "ranking" ? (
            <RankBoard rankings={rankings} />
          ) : (
            <RewardTab slots={slots} />
          )}
        </div>
        {tab === "ranking" ? <MyRankBar me={me} /> : null}
      </div>
    </div>
  );
}

function Header({
  title,
  endAt,
  winner,
}: {
  title: string;
  endAt: string | null;
  winner: RankRow | null;
}) {
  return (
    <div>
      <div className="relative h-[360px] w-full">
        <img
          src={A.hero}
          alt=""
          className="absolute inset-0 h-full w-full object-cover object-top"
        />
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-[#0A0618]" />
        <div className="relative z-10 flex h-full flex-col">
          <h1 className="px-4 pt-10 text-center text-lg font-black tracking-wide drop-shadow-[0_0_10px_#ff4081aa]">
            {title || "14 August"}
          </h1>
          <div className="flex flex-1 items-center justify-center">
            <WinnerSpotlight winner={winner} />
          </div>
        </div>
      </div>
      <Timer endAt={endAt} />
    </div>
  );
}

function WinnerSpotlight({ winner }: { winner: RankRow | null }) {
  const name = winner?.username?.trim() || "TEAM STAR";
  return (
    <div className="relative h-[200px] w-[260px]">
      <div
        className="absolute left-1/2 top-[28%] h-[99px] w-[99px] -translate-x-1/2 overflow-hidden rounded-full bg-[#1A0A2E] shadow-lg"
      >
        {winner?.avatar_url ? (
          <img
            src={winner.avatar_url}
            alt=""
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-[#2A1450] text-center text-[13px] font-black leading-tight text-[#FFD54F]">
            TEAM
            <br />
            STAR
          </div>
        )}
      </div>
      <img
        src={A.topFrame}
        alt=""
        className="absolute inset-0 h-full w-full object-contain"
      />
      <div className="absolute bottom-[11%] left-[22%] right-[22%] flex h-[28px] items-center justify-center">
        <p className="truncate text-center text-xs font-black drop-shadow">
          {name}
        </p>
      </div>
    </div>
  );
}

function Timer({ endAt }: { endAt: string | null }) {
  const [remaining, setRemaining] = useState(() => remainingFrom(endAt));

  useEffect(() => {
    const tick = () => setRemaining(remainingFrom(endAt));
    tick();
    const id = window.setInterval(tick, 1000);
    return () => window.clearInterval(id);
  }, [endAt]);

  const d = Math.floor(remaining / 86400);
  const h = Math.floor((remaining % 86400) / 3600);
  const m = Math.floor((remaining % 3600) / 60);
  const s = remaining % 60;

  return (
    <div className="mb-3 mt-2 flex items-start justify-center gap-1">
      <TimerBox value={d} label="Day" />
      <Colon />
      <TimerBox value={h} label="Hour" />
      <Colon />
      <TimerBox value={m} label="Minute" />
      <Colon />
      <TimerBox value={s} label="Second" />
    </div>
  );
}

function remainingFrom(endAt: string | null): number {
  if (!endAt) return 0;
  const diff = new Date(endAt).getTime() - Date.now();
  return diff > 0 ? Math.floor(diff / 1000) : 0;
}

function Colon() {
  return (
    <span className="px-1 pt-3 text-lg font-bold text-white">:</span>
  );
}

function TimerBox({ value, label }: { value: number; label: string }) {
  return (
    <div className="flex flex-col items-center">
      <div
        className="flex h-[52px] w-[52px] items-center justify-center bg-cover bg-center text-lg font-black drop-shadow"
        style={{ backgroundImage: `url(${A.timer})` }}
      >
        {String(value).padStart(2, "0")}
      </div>
      <span className="mt-1 text-[10px] font-semibold text-white/85">
        {label}
      </span>
    </div>
  );
}

function GiftsRules({ gifts, rules }: { gifts: GiftItem[]; rules: string }) {
  const slots = [0.175, 0.392, 0.608, 0.825];
  return (
    <div className="mx-3 mb-3">
      <div
        className="relative w-full overflow-hidden"
        style={{ aspectRatio: "1404 / 1120" }}
      >
        <img src={A.rules} alt="" className="absolute inset-0 h-full w-full" />
        <div className="absolute left-[22%] top-[9%] flex h-[9%] w-[56%] items-center justify-center text-sm font-black drop-shadow">
          Event Gift
        </div>
        {slots.map((x, i) => {
          const gift = gifts[i];
          return (
            <div
              key={i}
              className="absolute flex w-[14%] flex-col items-center"
              style={{ left: `${x * 100 - 7}%`, top: "29.5%" }}
            >
              <div className="aspect-square w-full">
                {gift?.imageUrl ? (
                  <img
                    src={gift.imageUrl}
                    alt={gift.name}
                    className="h-full w-full object-contain"
                  />
                ) : (
                  <div className="h-full w-full rounded-md bg-white/5" />
                )}
              </div>
              <div className="mt-1 flex items-center gap-0.5 text-[10px] font-extrabold">
                <span className="text-[#FFD54F]">★</span>
                {gift ? formatScore(gift.points) : "--"}
              </div>
            </div>
          );
        })}
        <div className="absolute inset-x-[12%] bottom-[14%] top-[58%] overflow-y-auto overscroll-contain text-[11px] font-medium leading-[1.45] text-white [text-shadow:0_1px_2px_rgba(0,0,0,0.45)] whitespace-pre-wrap [-webkit-overflow-scrolling:touch]">
          {rules}
        </div>
      </div>
    </div>
  );
}

function Tabs({ tab, onChange }: { tab: Tab; onChange: (t: Tab) => void }) {
  return (
    <div className="mx-3 mb-2.5 flex gap-2">
      <TabBtn
        label="Ranking"
        selected={tab === "ranking"}
        onClick={() => onChange("ranking")}
      />
      <TabBtn
        label="Reward"
        selected={tab === "reward"}
        onClick={() => onChange("reward")}
      />
    </div>
  );
}

function TabBtn({
  label,
  selected,
  onClick,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`relative h-12 flex-1 text-[11px] font-black ${
        selected ? "text-white" : "text-black"
      }`}
    >
      <img
        src={selected ? A.focus : A.button}
        alt=""
        className="pointer-events-none absolute inset-0 h-full w-full object-fill"
      />
      <span className="relative z-10 px-3">{label}</span>
    </button>
  );
}

const TOP3_ASPECT = 860 / 1828;

function RankBoard({ rankings }: { rankings: RankRow[] }) {
  const t1 = rankings[0];
  const t2 = rankings[1];
  const t3 = rankings[2];
  const rest = rankings.slice(3);
  const podium = [
    { user: t1, left: 0.38, top: 0.165, size: 0.24, label: "TOP 1", plate: "#C62828" },
    { user: t2, left: 0.09, top: 0.275, size: 0.2, label: "TOP 2", plate: "#1565C0" },
    { user: t3, left: 0.71, top: 0.275, size: 0.2, label: "TOP 3", plate: "#2E7D32" },
  ] as const;

  return (
    <div className="mx-2 mb-4">
      <div className="relative w-full" style={{ aspectRatio: `${860} / ${1828}` }}>
        {podium.map((p) => (
          <PodiumAvatar
            key={p.label}
            user={p.user}
            left={p.left}
            top={p.top}
            size={p.size}
          />
        ))}
        <img src={A.top3} alt="" className="absolute inset-0 h-full w-full" />
        {podium.map((p) => (
          <PodiumLabel
            key={`${p.label}-text`}
            user={p.user}
            rankLabel={p.label}
            left={p.left}
            top={p.top + p.size * TOP3_ASPECT * 1.02}
            size={p.size}
            plate={p.plate}
          />
        ))}
        <div className="absolute inset-x-[7%] bottom-[5.5%] top-[42%] overflow-y-auto">
          {rest.length === 0 ? (
            <p className="pt-8 text-center text-white/50">No rankings yet.</p>
          ) : (
            rest.map((u) => <RankRowItem key={u.user_id} user={u} />)
          )}
        </div>
      </div>
    </div>
  );
}

function PodiumAvatar({
  user,
  left,
  top,
  size,
}: {
  user?: RankRow;
  left: number;
  top: number;
  size: number;
}) {
  const avatar = size * 0.78;
  return (
    <div
      className="absolute overflow-hidden rounded-full bg-black/45"
      style={{
        left: `${(left + (size - avatar) / 2) * 100}%`,
        top: `${top * 100}%`,
        width: `${avatar * 100}%`,
        aspectRatio: "1",
      }}
    >
      {user?.avatar_url ? (
        <img src={user.avatar_url} alt="" className="h-full w-full object-cover" />
      ) : (
        <div className="flex h-full w-full items-center justify-center text-white/50">
          ●
        </div>
      )}
    </div>
  );
}

function PodiumLabel({
  user,
  rankLabel,
  left,
  top,
  size,
  plate,
}: {
  user?: RankRow;
  rankLabel: string;
  left: number;
  top: number;
  size: number;
  plate: string;
}) {
  return (
    <div
      className="absolute z-10 text-center"
      style={{
        left: `${(left - size * 0.08) * 100}%`,
        top: `${top * 100}%`,
        width: `${size * 1.16 * 100}%`,
      }}
    >
      <p
        className="font-black tracking-wide text-[#FFD54F]"
        style={{
          fontSize: `${Math.max(11, size * 80)}px`,
          textShadow: "0 2px 0 #5D4037, 0 0 6px #000",
        }}
      >
        {rankLabel}
      </p>
      <div
        className="mx-auto mt-0.5 max-w-full truncate rounded-full px-2 py-0.5 text-[10px] font-bold"
        style={{ backgroundColor: plate }}
      >
        {user?.username?.trim() || "--"}
      </div>
      <p className="mt-0.5 text-[10px] font-extrabold">
        ★ {user ? formatScore(user.score) : "--"}
      </p>
    </div>
  );
}

function RankRowItem({ user }: { user: RankRow }) {
  return (
    <div className="mb-1.5 flex items-center gap-2 rounded-xl bg-black/25 px-2 py-1.5">
      <span className="w-7 text-center text-sm font-black">{user.rank}</span>
      <div className="h-9 w-9 overflow-hidden rounded-full bg-black/40">
        {user.avatar_url ? (
          <img src={user.avatar_url} alt="" className="h-full w-full object-cover" />
        ) : null}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-extrabold">
          {user.username?.trim() || "User"}
        </p>
        <p className="text-[11px] text-white/70">ID {user.short_id || "--"}</p>
      </div>
      <span className="text-[#FFD54F]">★</span>
      <span className="text-sm font-black">{formatScore(user.score)}</span>
    </div>
  );
}

function RewardTab({ slots }: { slots: RewardSlots }) {
  const hasAny =
    slots.rank1Items.length ||
    slots.rank2Items.length ||
    slots.rank3Items.length ||
    slots.rank4to10Items.length;

  if (!hasAny) {
    return (
      <p className="px-6 py-10 text-center text-white/50">
        Rewards coming soon. Admin can set Top 1–3 and Top 4~10 rewards.
      </p>
    );
  }

  return (
    <div className="space-y-3.5 px-3 pb-6">
      {slots.rank1Items.length > 0 ? (
        <RewardFrame
          src={A.reward7}
          aspect="1024 / 1536"
          title={slots.rank1Label}
          items={slots.rank1Items}
          max={7}
          slotFrac={0.18}
          positions={[
            [0.22, 0.30],
            [0.5, 0.30],
            [0.78, 0.30],
            [0.22, 0.56],
            [0.5, 0.56],
            [0.78, 0.56],
            [0.5, 0.78],
          ]}
        />
      ) : null}
      {slots.rank2Items.length > 0 ? (
        <RewardFrame
          src={A.reward5}
          aspect="1176 / 1337"
          title={slots.rank2Label}
          items={slots.rank2Items}
          max={5}
          slotFrac={0.18}
          positions={[
            [0.22, 0.36],
            [0.5, 0.36],
            [0.78, 0.36],
            [0.35, 0.66],
            [0.65, 0.66],
          ]}
        />
      ) : null}
      {slots.rank3Items.length > 0 ? (
        <RewardFrame
          src={A.reward5}
          aspect="1176 / 1337"
          title={slots.rank3Label}
          items={slots.rank3Items}
          max={5}
          slotFrac={0.18}
          positions={[
            [0.22, 0.36],
            [0.5, 0.36],
            [0.78, 0.36],
            [0.35, 0.66],
            [0.65, 0.66],
          ]}
        />
      ) : null}
      {slots.rank4to10Items.length > 0 ? (
        <RewardFrame
          src={A.reward2}
          aspect="1536 / 1024"
          title={slots.rank4to10Label}
          items={slots.rank4to10Items}
          max={2}
          slotFrac={0.22}
          titleTop={0.08}
          positions={[
            [0.35, 0.52],
            [0.65, 0.52],
          ]}
        />
      ) : null}
    </div>
  );
}

function RewardFrame({
  src,
  aspect,
  title,
  items,
  max,
  slotFrac,
  positions,
  titleTop = 0.035,
}: {
  src: string;
  aspect: string;
  title: string;
  items: RewardItem[];
  max: number;
  slotFrac: number;
  positions: [number, number][];
  titleTop?: number;
}) {
  const shown = items.slice(0, max);
  return (
    <div className="relative w-full" style={{ aspectRatio: aspect }}>
      <img src={src} alt="" className="absolute inset-0 h-full w-full" />
      <div
        className="absolute left-[20%] w-[60%] text-center text-[15px] font-black drop-shadow"
        style={{ top: `${titleTop * 100}%` }}
      >
        {title}
      </div>
      {shown.map((item, i) => {
        const pos = positions[i];
        if (!pos) return null;
        return (
          <div
            key={`${item.label}-${i}`}
            className="absolute flex flex-col items-center"
            style={{
              left: `${(pos[0] - slotFrac / 2) * 100}%`,
              top: `${(pos[1] - slotFrac / 2) * 100}%`,
              width: `${slotFrac * 100}%`,
            }}
          >
            <div className="aspect-square w-full">
              {item.imageUrl ? (
                <img
                  src={item.imageUrl}
                  alt=""
                  className="h-full w-full object-contain"
                />
              ) : null}
            </div>
            {item.label ? (
              <p className="mt-0.5 truncate text-center text-[10px] font-bold">
                {item.label}
              </p>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}

function MyRankBar({ me }: { me: RankRow | null }) {
  const name = me?.username?.trim() || "User";
  const rankText = me && me.rank > 0 ? String(me.rank) : "--";
  return (
    <div className="sticky bottom-0 z-20 px-2 pb-[max(8px,env(safe-area-inset-bottom))]">
      <div className="flex items-center gap-2 rounded-2xl border border-[#FFD54F] bg-gradient-to-r from-[#7B1FA2] via-[#E91E63] to-[#7B1FA2] px-3.5 py-2.5 shadow-lg">
        <span className="w-7 text-center text-base font-black">{rankText}</span>
        <div className="h-[42px] w-[42px] overflow-hidden rounded-full border-[1.5px] border-white bg-black/25">
          {me?.avatar_url ? (
            <img src={me.avatar_url} alt="" className="h-full w-full object-cover" />
          ) : null}
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-extrabold">{name}</p>
          <p className="text-[11px] text-white/80">ID {me?.short_id || "--"}</p>
        </div>
        <span className="text-[#FFD54F]">★</span>
        <span className="text-sm font-black">{formatScore(me?.score ?? 0)}</span>
      </div>
    </div>
  );
}
