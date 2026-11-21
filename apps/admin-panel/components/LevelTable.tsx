"use client";
import { CdnImg } from "@/components/CdnImg";
import { Fragment, useState } from "react";
import { Edit2, Trash2, Check, X, Plus, Image as ImageIcon, Loader2 } from "lucide-react";
import {
  updateLevelConfig,
  deleteLevelConfig,
  addLevelConfig,
  type LevelRewardsMap,
} from "@/lib/actions/levels";
import { uploadFile } from "@/app/shop/actions";
import { ShopItemPickerModal, type ShopPickerItem } from "@/components/ShopItemPickerModal";
import { LevelRewardsEditor, LevelRewardsSummary } from "@/components/LevelRewardsEditor";
import { toast } from "sonner";
interface LevelTableProps {
  category: string;
  initialLevels: any[];
}
type RewardKey = "frame" | "bubble" | "card_background" | "entrance";
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
function hasRewardSupport(category: string) {
  return category === "wealth" || category === "charm";
}
function tableColSpan(category: string, hasTitle: boolean) {
  let count = 4;
  if (hasTitle) count += 1;
  if (["wealth", "charm", "cp"].includes(category)) count += 1;
  if (hasRewardSupport(category)) count += 1;
  return count;
}
export function LevelTable({ category, initialLevels }: LevelTableProps) {
  const [levels, setLevels] = useState(initialLevels);
  const [editingLevel, setEditingLevel] = useState<number | null>(null);
  const [editData, setEditData] = useState<any>(null);
  const [isAdding, setIsAdding] = useState(false);
  const [newData, setNewData] = useState<any>({
    level: initialLevels.length + 1,
    min_exp: 0,
    badge_url: "",
    rewards: emptyRewards(),
  });
  const [uploading, setUploading] = useState(false);
  const [picker, setPicker] = useState<{
    featureKey: RewardKey;
    isNew: boolean;
  } | null>(null);
  const handleEdit = (level: any) => {
    setEditingLevel(level.level);
    setEditData({
      ...level,
      rewards: { ...emptyRewards(), ...(level.rewards ?? {}) },
    });
  };
  const handleSave = async () => {
    try {
      const { level, id, created_at, category: cat, ...updateData } = editData;
      await updateLevelConfig(category, level, updateData);
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
      await deleteLevelConfig(category, level);
      setLevels(levels.filter((l) => l.level !== level));
      toast.success(`Level ${level} deleted`);
    } catch (error: any) {
      toast.error(error.message);
    }
  };
  const handleAdd = async () => {
    try {
      await addLevelConfig(category, newData);
      setLevels([...levels, newData].sort((a, b) => a.level - b.level));
      setIsAdding(false);
      setNewData({
        level: levels.length + 2,
        min_exp: 0,
        badge_url: "",
        rewards: emptyRewards(),
      });
      toast.success(`Level ${newData.level} added`);
    } catch (error: any) {
      toast.error(error.message);
    }
  };
  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>, isNew: boolean) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await uploadFile(formData);
      if (res.success && res.url) {
        if (isNew) {
          setNewData({ ...newData, badge_url: res.url });
        } else {
          setEditData({ ...editData, badge_url: res.url });
        }
        toast.success("Badge uploaded successfully");
      } else {
        throw new Error(res.error || "Upload failed");
      }
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setUploading(false);
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
  const hasTitle = levels[0]?.title !== undefined;
  const colspan = tableColSpan(category, hasTitle);
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold capitalize tracking-tight text-white/80">
          {category} Levels
        </h2>
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
                {levels[0]?.title !== undefined && (
                  <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                    Title
                  </th>
                )}
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Min EXP
                </th>
                <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Required for Next
                </th>
                {["wealth", "charm", "cp"].includes(category) && (
                  <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                    Badge Asset
                  </th>
                )}
                {hasRewardSupport(category) && (
                  <th className="px-4 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                    Rewards (4)
                  </th>
                )}
                <th className="px-4 py-4 text-right text-[10px] font-black uppercase tracking-widest text-white/30">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {isAdding && (
                <>
                  <tr className="bg-white/5">
                    <td className="px-4 py-4 font-bold text-white/40">
                      <input
                        type="number"
                        value={newData.level}
                        onChange={(e) =>
                          setNewData({
                            ...newData,
                            level: parseInt(e.target.value),
                          })
                        }
                        className="w-20 rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                      />
                    </td>
                    {levels[0]?.title !== undefined && (
                      <td className="px-4 py-4">
                        <input
                          type="text"
                          value={newData.title || ""}
                          onChange={(e) => setNewData({ ...newData, title: e.target.value })}
                          className="w-full rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                          placeholder="Title"
                        />
                      </td>
                    )}
                    <td className="px-4 py-4">
                      <input
                        type="number"
                        value={newData.min_exp}
                        onChange={(e) =>
                          setNewData({
                            ...newData,
                            min_exp: parseInt(e.target.value),
                          })
                        }
                        className="w-full rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                      />
                    </td>
                    <td className="px-4 py-4">
                      <span className="font-mono text-sm text-white/10">-</span>
                    </td>
                    {["wealth", "charm", "cp"].includes(category) && (
                      <td className="px-4 py-4">
                        <div className="flex items-center gap-3">
                          {newData.badge_url ? (
                            <CdnImg
                              src={newData.badge_url}
                              alt="New Badge"
                              className="h-8 w-8 object-contain"
                            />
                          ) : (
                            <div className="flex h-8 w-8 items-center justify-center rounded bg-white/5 text-white/20">
                              <ImageIcon size={14} />
                            </div>
                          )}
                          <label className="cursor-pointer rounded-lg bg-white/5 p-2 transition-colors hover:bg-white/10">
                            {uploading ? (
                              <Loader2 size={14} className="animate-spin" />
                            ) : (
                              <ImageIcon size={14} />
                            )}
                            <input
                              type="file"
                              className="hidden"
                              accept="image/*"
                              onChange={(e) => handleFileUpload(e, true)}
                              disabled={uploading}
                            />
                          </label>
                        </div>
                      </td>
                    )}
                    {hasRewardSupport(category) && (
                      <td className="px-4 py-4">
                        <LevelRewardsSummary rewards={newData.rewards} />
                      </td>
                    )}
                    <td className="px-4 py-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={handleAdd}
                          className="rounded-lg bg-green-500/20 p-2 text-green-400 transition-colors hover:bg-green-500/40"
                        >
                          <Check size={16} />
                        </button>
                        <button
                          onClick={() => setIsAdding(false)}
                          className="rounded-lg bg-red-500/20 p-2 text-red-400 transition-colors hover:bg-red-500/40"
                        >
                          <X size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                  {hasRewardSupport(category) && (
                    <tr className="bg-white/5">
                      <td colSpan={colspan} className="px-4 pb-4">
                        <LevelRewardsEditor
                          rewards={newData.rewards ?? emptyRewards()}
                          onSelect={(key) => setPicker({ featureKey: key, isNew: true })}
                          onClear={(key) => setReward(true, key, null)}
                        />
                      </td>
                    </tr>
                  )}
                </>
              )}

              {levels.map((level, index) => {
                const isEditing = editingLevel === level.level;
                return (
                  <Fragment key={level.level}>
                    <tr className="group transition-colors hover:bg-white/[0.02]">
                      <td className="px-4 py-4">
                        <span className="text-sm font-black text-white/60">Lv. {level.level}</span>
                      </td>
                      {level.title !== undefined && (
                        <td className="px-4 py-4">
                          {isEditing ? (
                            <input
                              type="text"
                              value={editData.title}
                              onChange={(e) => setEditData({ ...editData, title: e.target.value })}
                              className="w-full rounded border border-white/10 bg-black/40 px-2 py-1 text-white"
                            />
                          ) : (
                            <span className="text-sm text-white/60">{level.title}</span>
                          )}
                        </td>
                      )}
                      <td className="px-4 py-4">
                        {isEditing ? (
                          <input
                            type="number"
                            value={editData.min_exp}
                            onChange={(e) =>
                              setEditData({
                                ...editData,
                                min_exp: parseInt(e.target.value),
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
                      {["wealth", "charm", "cp"].includes(category) && (
                        <td className="px-4 py-4">
                          <div className="flex items-center gap-3">
                            {isEditing ? (
                              <>
                                {editData.badge_url ? (
                                  <CdnImg
                                    src={editData.badge_url}
                                    alt="Badge"
                                    className="h-8 w-8 object-contain"
                                  />
                                ) : (
                                  <div className="flex h-8 w-8 items-center justify-center rounded bg-white/5 text-white/20">
                                    <ImageIcon size={14} />
                                  </div>
                                )}
                                <label className="cursor-pointer rounded-lg bg-white/5 p-2 transition-colors hover:bg-white/10">
                                  {uploading ? (
                                    <Loader2 size={14} className="animate-spin" />
                                  ) : (
                                    <ImageIcon size={14} />
                                  )}
                                  <input
                                    type="file"
                                    className="hidden"
                                    accept="image/*"
                                    onChange={(e) => handleFileUpload(e, false)}
                                    disabled={uploading}
                                  />
                                </label>
                              </>
                            ) : level.badge_url ? (
                              <CdnImg
                                src={level.badge_url}
                                alt="Badge"
                                className="h-8 w-8 object-contain"
                              />
                            ) : (
                              <span className="text-[10px] italic text-white/10">No Badge</span>
                            )}
                          </div>
                        </td>
                      )}
                      {hasRewardSupport(category) && (
                        <td className="px-4 py-4">
                          <LevelRewardsSummary
                            rewards={isEditing ? editData.rewards : level.rewards}
                          />
                        </td>
                      )}
                      <td className="px-4 py-4 text-right">
                        <div className="flex items-center justify-end gap-2 opacity-0 transition-opacity group-hover:opacity-100">
                          {isEditing ? (
                            <>
                              <button
                                onClick={handleSave}
                                className="rounded-lg bg-green-500/20 p-2 text-green-400 transition-colors hover:bg-green-500/40"
                              >
                                <Check size={16} />
                              </button>
                              <button
                                onClick={() => setEditingLevel(null)}
                                className="rounded-lg bg-red-500/20 p-2 text-red-400 transition-colors hover:bg-red-500/40"
                              >
                                <X size={16} />
                              </button>
                            </>
                          ) : (
                            <>
                              <button
                                onClick={() => handleEdit(level)}
                                className="rounded-lg bg-white/5 p-2 text-white/40 transition-colors hover:bg-white/10 hover:text-white"
                              >
                                <Edit2 size={16} />
                              </button>
                              <button
                                onClick={() => handleDelete(level.level)}
                                className="rounded-lg bg-red-500/20 p-2 text-red-400 transition-colors hover:bg-red-500/40"
                              >
                                <Trash2 size={16} />
                              </button>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                    {isEditing && hasRewardSupport(category) && (
                      <tr key={`${level.level}-rewards`} className="bg-white/[0.03]">
                        <td colSpan={colspan} className="px-4 pb-4">
                          <LevelRewardsEditor
                            rewards={editData.rewards ?? emptyRewards()}
                            onSelect={(key) => setPicker({ featureKey: key, isNew: false })}
                            onClear={(key) => setReward(false, key, null)}
                          />
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
