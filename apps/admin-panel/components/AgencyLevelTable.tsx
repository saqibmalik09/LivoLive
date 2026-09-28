"use client";
import { Fragment, useState } from "react";
import { Edit2, Trash2, Check, X, Plus, Image as ImageIcon, Loader2 } from "lucide-react";
import {
  updateLevelConfig,
  deleteLevelConfig,
  addLevelConfig,
  type AgencyProfileFrames,
  type LevelRewardsMap,
} from "@/lib/actions/levels";
import { uploadFile } from "@/app/shop/actions";
import { ShopItemPickerModal, type ShopPickerItem } from "@/components/ShopItemPickerModal";
import { LevelRewardsEditor, LevelRewardsSummary } from "@/components/LevelRewardsEditor";
import { toast } from "sonner";
type ProfileFrameKey = "hero_frame" | "honor_frame" | "charm_frame";
type RewardKey = "frame" | "bubble" | "card_background" | "entrance";
const PROFILE_FRAME_LABELS: Record<ProfileFrameKey, string> = {
  hero_frame: "Hero Frame",
  honor_frame: "Honor Frame",
  charm_frame: "Charm Frame",
};
const PROFILE_FRAME_KEYS: ProfileFrameKey[] = ["hero_frame", "honor_frame", "charm_frame"];
const REWARD_LABELS: Record<RewardKey, string> = {
  frame: "Frame",
  bubble: "Bubble",
  card_background: "Card Background",
  entrance: "Entrance",
};
const emptyRewards = (): LevelRewardsMap => ({
  frame: null,
  bubble: null,
  card_background: null,
  entrance: null,
});
const emptyProfileFrames = (): AgencyProfileFrames => ({
  hero_frame: null,
  honor_frame: null,
  charm_frame: null,
});
interface AgencyLevelTableProps {
  initialLevels: any[];
}
export function AgencyLevelTable({ initialLevels }: AgencyLevelTableProps) {
  const [levels, setLevels] = useState(initialLevels);
  const [editingLevel, setEditingLevel] = useState<number | null>(null);
  const [editData, setEditData] = useState<any>(null);
  const [isAdding, setIsAdding] = useState(false);
  const [newData, setNewData] = useState<any>({
    level: initialLevels.length + 1,
    min_exp: 0,
    tier_name: "Bronze Agency",
    badge_url: "",
    profile_frames: emptyProfileFrames(),
    rewards: emptyRewards(),
  });
  const [uploading, setUploading] = useState<string | null>(null);
  const [picker, setPicker] = useState<{
    featureKey: RewardKey;
    isNew: boolean;
  } | null>(null);
  const colspan = 7;
  const handleEdit = (level: any) => {
    setEditingLevel(level.level);
    setEditData({
      ...level,
      profile_frames: {
        ...emptyProfileFrames(),
        ...(level.profile_frames ?? {}),
      },
      rewards: { ...emptyRewards(), ...(level.rewards ?? {}) },
    });
  };
  const handleSave = async () => {
    try {
      const { level, id, created_at, ...updateData } = editData;
      await updateLevelConfig("agency", level, updateData);
      setLevels(levels.map((l) => (l.level === level ? { ...l, ...updateData } : l)));
      setEditingLevel(null);
      toast.success(`Level ${level} updated`);
    } catch (error: any) {
      toast.error(error.message);
    }
  };
  const handleDelete = async (level: number) => {
    if (!confirm(`Are you sure you want to delete level ${level}?`)) return;
    try {
      await deleteLevelConfig("agency", level);
      setLevels(levels.filter((l) => l.level !== level));
      toast.success(`Level ${level} deleted`);
    } catch (error: any) {
      toast.error(error.message);
    }
  };
  const handleAdd = async () => {
    try {
      await addLevelConfig("agency", newData);
      setLevels([...levels, newData].sort((a, b) => a.level - b.level));
      setIsAdding(false);
      setNewData({
        level: levels.length + 2,
        min_exp: 0,
        tier_name: "Bronze Agency",
        badge_url: "",
        profile_frames: emptyProfileFrames(),
        rewards: emptyRewards(),
      });
      toast.success(`Level ${newData.level} added`);
    } catch (error: any) {
      toast.error(error.message);
    }
  };
  const handleFileUpload = async (
    e: React.ChangeEvent<HTMLInputElement>,
    field: "badge" | ProfileFrameKey,
    isNew: boolean,
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(field);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await uploadFile(formData);
      if (res.success && res.url) {
        if (isNew) {
          if (field === "badge") {
            setNewData({ ...newData, badge_url: res.url });
          } else {
            setNewData({
              ...newData,
              profile_frames: {
                ...(newData.profile_frames ?? emptyProfileFrames()),
                [field]: res.url,
              },
            });
          }
        } else if (field === "badge") {
          setEditData({ ...editData, badge_url: res.url });
        } else {
          setEditData({
            ...editData,
            profile_frames: {
              ...(editData.profile_frames ?? emptyProfileFrames()),
              [field]: res.url,
            },
          });
        }
        toast.success("Asset uploaded");
      } else {
        throw new Error(res.error || "Upload failed");
      }
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setUploading(null);
      e.target.value = "";
    }
  };
  const setReward = (isNew: boolean, key: RewardKey, item: ShopPickerItem | null) => {
    if (isNew) {
      setNewData({
        ...newData,
        rewards: {
          ...(newData.rewards ?? emptyRewards()),
          [key]: item ? { id: item.id, name: item.name, image_url: item.image_url } : null,
        },
      });
    } else {
      setEditData({
        ...editData,
        rewards: {
          ...(editData.rewards ?? emptyRewards()),
          [key]: item ? { id: item.id, name: item.name, image_url: item.image_url } : null,
        },
      });
    }
  };
  const renderAssetThumb = (url?: string | null) =>
    url ? (
      <img src={url} alt="" className="h-8 w-8 object-contain" />
    ) : (
      <div className="flex h-8 w-8 items-center justify-center rounded bg-white/5 text-white/20">
        <ImageIcon size={14} />
      </div>
    );
  const renderUploadButton = (
    field: "badge" | ProfileFrameKey,
    isNew: boolean,
    accept = "image/*,.svga,application/octet-stream",
  ) => (
    <label className="cursor-pointer rounded-lg bg-white/5 p-2 transition-colors hover:bg-white/10">
      {uploading === field ? (
        <Loader2 size={14} className="animate-spin" />
      ) : (
        <ImageIcon size={14} />
      )}
      <input
        type="file"
        className="hidden"
        accept={accept}
        onChange={(e) => handleFileUpload(e, field, isNew)}
        disabled={uploading === field}
      />
    </label>
  );
  const renderProfileFramesRow = (frames: AgencyProfileFrames, isNew: boolean) => (
    <div className="flex flex-wrap gap-4">
      {PROFILE_FRAME_KEYS.map((key) => (
        <div key={key} className="flex items-center gap-2">
          <span className="text-[10px] uppercase tracking-wider text-white/40">
            {PROFILE_FRAME_LABELS[key]}
          </span>
          {renderAssetThumb(frames[key])}
          {renderUploadButton(key, isNew)}
        </div>
      ))}
    </div>
  );
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold tracking-tight text-white/80">Agency Levels</h2>
        <button
          onClick={() => setIsAdding(true)}
          className="flex items-center gap-2 rounded-xl bg-white/10 px-4 py-2 text-xs font-bold uppercase tracking-widest text-white transition-all hover:bg-white/20"
        >
          <Plus size={16} /> Add Level
        </button>
      </div>

      <div className="glass-card overflow-hidden border border-white/5 p-0 shadow-2xl">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-white/5 bg-white/5">
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Level
                </th>
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Tier Name
                </th>
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Min EXP
                </th>
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Next EXP
                </th>
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Badge
                </th>
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Rewards
                </th>
                <th className="px-4 py-4 text-right text-[10px] font-black uppercase tracking-widest text-white/30">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {isAdding && (
                <>
                  <tr className="bg-white/5">
                    <td className="px-4 py-4">
                      <input
                        type="number"
                        value={newData.level}
                        onChange={(e) =>
                          setNewData({ ...newData, level: parseInt(e.target.value, 10) })
                        }
                        className="w-20 rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                      />
                    </td>
                    <td className="px-4 py-4">
                      <input
                        type="text"
                        value={newData.tier_name}
                        onChange={(e) => setNewData({ ...newData, tier_name: e.target.value })}
                        className="w-full min-w-[140px] rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                      />
                    </td>
                    <td className="px-4 py-4">
                      <input
                        type="number"
                        value={newData.min_exp}
                        onChange={(e) =>
                          setNewData({ ...newData, min_exp: parseInt(e.target.value, 10) })
                        }
                        className="w-full rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                      />
                    </td>
                    <td className="px-4 py-4 text-white/20">-</td>
                    <td className="px-4 py-4">
                      <div className="flex items-center gap-2">
                        {renderAssetThumb(newData.badge_url)}
                        {renderUploadButton("badge", true)}
                      </div>
                    </td>
                    <td className="px-4 py-4">
                      <LevelRewardsSummary rewards={newData.rewards} />
                    </td>
                    <td className="px-4 py-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={handleAdd}
                          className="rounded-lg bg-green-500/20 p-2 text-green-400 hover:bg-green-500/40"
                        >
                          <Check size={16} />
                        </button>
                        <button
                          onClick={() => setIsAdding(false)}
                          className="rounded-lg bg-red-500/20 p-2 text-red-400 hover:bg-red-500/40"
                        >
                          <X size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                  <tr className="bg-white/[0.03]">
                    <td colSpan={colspan} className="space-y-4 px-4 pb-4 pt-2">
                      <p className="text-[10px] font-bold uppercase tracking-widest text-white/30">
                        Profile Frames
                      </p>
                      {renderProfileFramesRow(newData.profile_frames ?? emptyProfileFrames(), true)}
                      <LevelRewardsEditor
                        rewards={newData.rewards ?? emptyRewards()}
                        onSelect={(key) => setPicker({ featureKey: key, isNew: true })}
                        onClear={(key) => setReward(true, key, null)}
                      />
                    </td>
                  </tr>
                </>
              )}

              {levels.map((level, index) => {
                const isEditing = editingLevel === level.level;
                const frames = isEditing
                  ? (editData.profile_frames ?? emptyProfileFrames())
                  : (level.profile_frames ?? emptyProfileFrames());
                return (
                  <Fragment key={level.level}>
                    <tr className="group transition-colors hover:bg-white/[0.02]">
                      <td className="px-4 py-4">
                        <span className="text-sm font-black text-white/60">Lv. {level.level}</span>
                      </td>
                      <td className="px-4 py-4">
                        {isEditing ? (
                          <input
                            type="text"
                            value={editData.tier_name}
                            onChange={(e) =>
                              setEditData({ ...editData, tier_name: e.target.value })
                            }
                            className="w-full min-w-[140px] rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                          />
                        ) : (
                          <span className="text-sm text-white/60">{level.tier_name}</span>
                        )}
                      </td>
                      <td className="px-4 py-4">
                        {isEditing ? (
                          <input
                            type="number"
                            value={editData.min_exp}
                            onChange={(e) =>
                              setEditData({
                                ...editData,
                                min_exp: parseInt(e.target.value, 10),
                              })
                            }
                            className="w-full rounded border border-white/10 bg-black/40 px-2 py-1 font-mono text-white"
                          />
                        ) : (
                          <span className="font-mono text-sm font-bold text-white/40">
                            {level.min_exp.toLocaleString()} EXP
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-4">
                        <span className="font-mono text-sm text-white/20">
                          {index + 1 < levels.length
                            ? (levels[index + 1].min_exp - level.min_exp).toLocaleString()
                            : "-"}
                        </span>
                      </td>
                      <td className="px-4 py-4">
                        <div className="flex items-center gap-2">
                          {isEditing ? (
                            <>
                              {renderAssetThumb(editData.badge_url)}
                              {renderUploadButton("badge", false)}
                            </>
                          ) : (
                            (renderAssetThumb(level.badge_url) ?? (
                              <span className="text-[10px] italic text-white/10">No Badge</span>
                            ))
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-4">
                        <LevelRewardsSummary
                          rewards={isEditing ? editData.rewards : level.rewards}
                        />
                      </td>
                      <td className="px-4 py-4 text-right">
                        <div className="flex items-center justify-end gap-2 opacity-0 transition-opacity group-hover:opacity-100">
                          {isEditing ? (
                            <>
                              <button
                                onClick={handleSave}
                                className="rounded-lg bg-green-500/20 p-2 text-green-400 hover:bg-green-500/40"
                              >
                                <Check size={16} />
                              </button>
                              <button
                                onClick={() => setEditingLevel(null)}
                                className="rounded-lg bg-red-500/20 p-2 text-red-400 hover:bg-red-500/40"
                              >
                                <X size={16} />
                              </button>
                            </>
                          ) : (
                            <>
                              <button
                                onClick={() => handleEdit(level)}
                                className="rounded-lg bg-white/5 p-2 text-white/40 hover:bg-white/10 hover:text-white"
                              >
                                <Edit2 size={16} />
                              </button>
                              <button
                                onClick={() => handleDelete(level.level)}
                                className="rounded-lg bg-red-500/20 p-2 text-red-400 hover:bg-red-500/40"
                              >
                                <Trash2 size={16} />
                              </button>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                    {isEditing && (
                      <tr className="bg-white/[0.03]">
                        <td colSpan={colspan} className="space-y-4 px-4 pb-4 pt-2">
                          <p className="text-[10px] font-bold uppercase tracking-widest text-white/30">
                            Profile Frames
                          </p>
                          {renderProfileFramesRow(frames, false)}
                          <LevelRewardsEditor
                            rewards={editData.rewards ?? emptyRewards()}
                            onSelect={(key) => setPicker({ featureKey: key, isNew: false })}
                            onClear={(key) => setReward(false, key, null)}
                          />
                        </td>
                      </tr>
                    )}
                    {!isEditing && (
                      <tr className="bg-white/[0.01]">
                        <td colSpan={colspan} className="px-4 pb-3 pt-0">
                          <div className="flex flex-wrap gap-4 opacity-60">
                            {PROFILE_FRAME_KEYS.map((key) => (
                              <div key={key} className="flex items-center gap-2">
                                <span className="text-[9px] uppercase text-white/30">
                                  {PROFILE_FRAME_LABELS[key]}
                                </span>
                                {frames[key] ? (
                                  renderAssetThumb(frames[key])
                                ) : (
                                  <span className="text-[9px] text-white/20">—</span>
                                )}
                              </div>
                            ))}
                          </div>
                        </td>
                      </tr>
                    )}
                  </Fragment>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {picker && (
        <ShopItemPickerModal
          open
          featureKey={picker.featureKey}
          title={`Select ${REWARD_LABELS[picker.featureKey]}`}
          onClose={() => setPicker(null)}
          onSelect={(item) => setReward(picker.isNew, picker.featureKey, item)}
        />
      )}
    </div>
  );
}
