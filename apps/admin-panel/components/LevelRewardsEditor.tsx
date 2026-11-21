"use client";
import { CdnImg } from "@/components/CdnImg";
import { Image as ImageIcon } from "lucide-react";
import type { LevelRewardsMap } from "@/lib/actions/levels";
const REWARD_SLOTS = [
  { key: "frame", label: "Frame" },
  { key: "bubble", label: "Bubble" },
  { key: "card_background", label: "Card Background" },
  { key: "entrance", label: "Entrance" },
] as const;
type RewardKey = (typeof REWARD_SLOTS)[number]["key"];
interface LevelRewardsEditorProps {
  rewards: LevelRewardsMap;
  onSelect: (key: RewardKey) => void;
  onClear: (key: RewardKey) => void;
}
export function LevelRewardsEditor({ rewards, onSelect, onClear }: LevelRewardsEditorProps) {
  return (
    <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
      <p className="mb-3 text-xs font-bold uppercase tracking-widest text-white/40">
        Level Rewards — assign up to 4 shop items
      </p>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        {REWARD_SLOTS.map((slot) => {
          const reward = rewards[slot.key];
          return (
            <div
              key={slot.key}
              className="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 p-3"
            >
              {reward?.image_url ? (
                <CdnImg
                  src={reward.image_url}
                  alt={reward.name ?? slot.label}
                  className="h-12 w-12 rounded-lg object-contain bg-black/20"
                />
              ) : (
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-white/5 text-white/20">
                  <ImageIcon size={16} />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <p className="text-xs font-bold uppercase tracking-wider text-amber-400/80">
                  {slot.label}
                </p>
                <p className="truncate text-sm text-white/70">{reward?.name ?? "Not assigned"}</p>
              </div>
              <div className="flex shrink-0 flex-col gap-1">
                <button
                  type="button"
                  onClick={() => onSelect(slot.key)}
                  className="rounded-lg bg-amber-500/20 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-amber-300 hover:bg-amber-500/30"
                >
                  Select
                </button>
                {reward && (
                  <button
                    type="button"
                    onClick={() => onClear(slot.key)}
                    className="rounded-lg bg-red-500/10 px-3 py-1 text-[10px] text-red-300 hover:bg-red-500/20"
                  >
                    Clear
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
export function LevelRewardsSummary({ rewards }: { rewards?: LevelRewardsMap }) {
  const filled = REWARD_SLOTS.filter((slot) => rewards?.[slot.key]?.id).length;
  return (
    <div className="flex items-center gap-2">
      <div className="flex items-center gap-1">
        {REWARD_SLOTS.map((slot) => {
          const reward = rewards?.[slot.key];
          return reward?.image_url ? (
            <CdnImg
              key={slot.key}
              src={reward.image_url}
              alt={slot.label}
              title={slot.label}
              className="h-7 w-7 rounded object-contain bg-black/20"
            />
          ) : (
            <div
              key={slot.key}
              title={slot.label}
              className="flex h-7 w-7 items-center justify-center rounded bg-white/5 text-[8px] text-white/20"
            >
              —
            </div>
          );
        })}
      </div>
      <span className="text-[10px] text-white/30">{filled}/4</span>
    </div>
  );
}
