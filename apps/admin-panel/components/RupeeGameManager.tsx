"use client";
import { useMemo, useState } from "react";
import {
  drawRupeeGameWinner,
  refundRupeeGameLosers,
  runAutoDrawEndedCampaigns,
  deleteRupeeGameCampaign,
  deleteRupeeGamePrize,
  listRupeeGamePrizes,
  updateRupeeGameHelpSection,
  uploadRupeeGameImage,
  upsertRupeeGameCampaign,
  upsertRupeeGamePrize,
  type RupeeGameCampaignInput,
  type RupeeGameHelpInput,
  type RupeeGamePrizeInput,
} from "@/lib/actions/rupee-game";
import { Loader2, Plus, Trash2, Upload, Wand2, RefreshCw } from "lucide-react";
import { toast } from "sonner";
type TabId = "campaigns" | "prizes" | "entries" | "help";
const emptyCampaign = (): RupeeGameCampaignInput => ({
  title: "Rupee Game",
  subtitle: "Get items worth a fortune for just a few coins",
  hero_image_url: "",
  entry_price_coins: 1,
  starts_at: new Date().toISOString().slice(0, 16),
  ends_at: new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 16),
  status: "draft",
  max_entries_per_user: 1,
  draw_mode: "manual",
  refund_non_winners: true,
  announcement_hours: 48,
  sort_order: 0,
  is_active: true,
});
const emptyPrize = (campaignId: string): RupeeGamePrizeInput => ({
  campaign_id: campaignId,
  name: "Prize",
  image_url: "",
  original_value_label: "100,000 coins",
  sort_order: 0,
  coming_soon: false,
});
interface RupeeGameManagerProps {
  initialCampaigns: any[];
  initialHelp: any[];
  initialEntries: any[];
}
export function RupeeGameManager({
  initialCampaigns,
  initialHelp,
  initialEntries,
}: RupeeGameManagerProps) {
  const [tab, setTab] = useState<TabId>("campaigns");
  const [campaigns, setCampaigns] = useState(initialCampaigns);
  const [helpSections, setHelpSections] = useState(initialHelp);
  const [entries] = useState(initialEntries);
  const [selectedCampaignId, setSelectedCampaignId] = useState<string>(
    initialCampaigns[0]?.id ?? "",
  );
  const [prizes, setPrizes] = useState<any[]>([]);
  const [loadingPrizes, setLoadingPrizes] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [drawUserId, setDrawUserId] = useState<Record<string, string>>({});
  const [editCampaign, setEditCampaign] = useState<RupeeGameCampaignInput | null>(null);
  const [editPrize, setEditPrize] = useState<RupeeGamePrizeInput | null>(null);
  const selectedCampaign = useMemo(
    () => campaigns.find((c) => c.id === selectedCampaignId),
    [campaigns, selectedCampaignId],
  );
  async function loadPrizes(campaignId: string) {
    if (!campaignId) return;
    setLoadingPrizes(true);
    try {
      const data = await listRupeeGamePrizes(campaignId);
      setPrizes(data);
    } catch {
      toast.error("Failed to load prizes");
    } finally {
      setLoadingPrizes(false);
    }
  }
  async function handleSaveCampaign() {
    if (!editCampaign) return;
    try {
      await upsertRupeeGameCampaign({
        ...editCampaign,
        starts_at: new Date(editCampaign.starts_at).toISOString(),
        ends_at: new Date(editCampaign.ends_at).toISOString(),
      });
      toast.success("Campaign saved");
      window.location.reload();
    } catch (e: any) {
      toast.error(e.message);
    }
  }
  async function handleSavePrize() {
    if (!editPrize) return;
    try {
      await upsertRupeeGamePrize(editPrize);
      toast.success("Prize saved");
      setEditPrize(null);
      await loadPrizes(editPrize.campaign_id);
    } catch (e: any) {
      toast.error(e.message);
    }
  }
  async function handleImageUpload(
    e: React.ChangeEvent<HTMLInputElement>,
    target: "campaign" | "prize",
  ) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const fd = new FormData();
      fd.append("file", file);
      const res = await uploadRupeeGameImage(fd);
      if (!res.success || !res.url) throw new Error(res.error || "Upload failed");
      if (target === "campaign" && editCampaign) {
        setEditCampaign({ ...editCampaign, hero_image_url: res.url });
      } else if (target === "prize" && editPrize) {
        setEditPrize({ ...editPrize, image_url: res.url });
      }
      toast.success("Image uploaded");
    } catch (err: any) {
      toast.error(err.message);
    } finally {
      setUploading(false);
      e.target.value = "";
    }
  }
  async function handleDraw(prizeId: string, random: boolean) {
    try {
      const userId = random ? null : drawUserId[prizeId] || null;
      const res = await drawRupeeGameWinner(prizeId, userId);
      if (!res?.success) throw new Error(res?.message || "Draw failed");
      toast.success("Winner drawn");
      await loadPrizes(selectedCampaignId);
    } catch (e: any) {
      toast.error(e.message);
    }
  }
  async function handleRefund(prizeId: string) {
    try {
      const res = await refundRupeeGameLosers(prizeId);
      if (!res?.success) throw new Error(res?.message || "Refund failed");
      toast.success(`Refunded ${res.refunded_count ?? 0} users`);
      await loadPrizes(selectedCampaignId);
    } catch (e: any) {
      toast.error(e.message);
    }
  }
  async function handleAutoDraw() {
    try {
      const res = await runAutoDrawEndedCampaigns();
      toast.success(`Auto draw complete (${res?.prizes_drawn ?? 0} prizes)`);
      window.location.reload();
    } catch (e: any) {
      toast.error(e.message);
    }
  }
  async function saveHelp(section: RupeeGameHelpInput) {
    try {
      await updateRupeeGameHelpSection(section);
      toast.success("Help section saved");
    } catch (e: any) {
      toast.error(e.message);
    }
  }
  const tabs: {
    id: TabId;
    label: string;
  }[] = [
    { id: "campaigns", label: "Campaigns" },
    { id: "prizes", label: "Prizes" },
    { id: "entries", label: "Entries" },
    { id: "help", label: "Help CMS" },
  ];
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-2 items-center justify-between">
        <div className="flex flex-wrap gap-2">
          {tabs.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => {
                setTab(t.id);
                if (t.id === "prizes" && selectedCampaignId) void loadPrizes(selectedCampaignId);
              }}
              className={`rounded-xl px-4 py-2 text-xs font-bold uppercase tracking-widest ${
                tab === t.id
                  ? "bg-amber-500/30 text-amber-200"
                  : "bg-white/5 text-white/40 hover:bg-white/10"
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={() => void handleAutoDraw()}
          className="flex items-center gap-2 rounded-xl bg-violet-500/20 px-4 py-2 text-xs font-bold text-violet-200 hover:bg-violet-500/30"
        >
          <Wand2 size={14} /> Run auto-draw (ended campaigns)
        </button>
      </div>

      {tab === "campaigns" && (
        <div className="space-y-4">
          <button
            type="button"
            onClick={() => setEditCampaign(emptyCampaign())}
            className="flex items-center gap-2 rounded-xl bg-white/10 px-4 py-2 text-sm"
          >
            <Plus size={16} /> New campaign
          </button>

          {editCampaign && (
            <div className="glass-card p-6 space-y-4 border border-white/10">
              <div className="grid gap-4 md:grid-cols-2">
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Title</span>
                  <input
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editCampaign.title}
                    onChange={(e) => setEditCampaign({ ...editCampaign, title: e.target.value })}
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Entry coins</span>
                  <input
                    type="number"
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editCampaign.entry_price_coins}
                    onChange={(e) =>
                      setEditCampaign({
                        ...editCampaign,
                        entry_price_coins: parseInt(e.target.value, 10) || 1,
                      })
                    }
                  />
                </label>
                <label className="space-y-1 text-sm md:col-span-2">
                  <span className="text-white/50">Subtitle</span>
                  <input
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editCampaign.subtitle}
                    onChange={(e) => setEditCampaign({ ...editCampaign, subtitle: e.target.value })}
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Starts</span>
                  <input
                    type="datetime-local"
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editCampaign.starts_at}
                    onChange={(e) =>
                      setEditCampaign({ ...editCampaign, starts_at: e.target.value })
                    }
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Ends</span>
                  <input
                    type="datetime-local"
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editCampaign.ends_at}
                    onChange={(e) => setEditCampaign({ ...editCampaign, ends_at: e.target.value })}
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Status</span>
                  <select
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editCampaign.status}
                    onChange={(e) =>
                      setEditCampaign({
                        ...editCampaign,
                        status: e.target.value as RupeeGameCampaignInput["status"],
                      })
                    }
                  >
                    <option value="draft">draft</option>
                    <option value="active">active</option>
                    <option value="ended">ended</option>
                    <option value="drawn">drawn</option>
                  </select>
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Draw mode</span>
                  <select
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editCampaign.draw_mode}
                    onChange={(e) =>
                      setEditCampaign({
                        ...editCampaign,
                        draw_mode: e.target.value as RupeeGameCampaignInput["draw_mode"],
                      })
                    }
                  >
                    <option value="manual">manual</option>
                    <option value="auto_random">auto_random</option>
                  </select>
                </label>
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={editCampaign.refund_non_winners}
                    onChange={(e) =>
                      setEditCampaign({
                        ...editCampaign,
                        refund_non_winners: e.target.checked,
                      })
                    }
                  />
                  Refund non-winners
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Hero image</span>
                  <div className="flex items-center gap-2">
                    {editCampaign.hero_image_url ? (
                      <img src={editCampaign.hero_image_url} alt="" className="h-12 rounded" />
                    ) : null}
                    <label className="cursor-pointer rounded-lg bg-white/10 p-2">
                      {uploading ? (
                        <Loader2 className="animate-spin" size={14} />
                      ) : (
                        <Upload size={14} />
                      )}
                      <input
                        type="file"
                        className="hidden"
                        accept="image/*"
                        onChange={(e) => void handleImageUpload(e, "campaign")}
                      />
                    </label>
                  </div>
                </label>
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => void handleSaveCampaign()}
                  className="rounded-lg bg-emerald-500/30 px-4 py-2 text-sm text-emerald-200"
                >
                  Save campaign
                </button>
                <button
                  type="button"
                  onClick={() => setEditCampaign(null)}
                  className="rounded-lg bg-white/10 px-4 py-2 text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          <div className="grid gap-4">
            {campaigns.map((c) => (
              <div
                key={c.id}
                className="glass-card p-4 border border-white/10 flex justify-between gap-4"
              >
                <div>
                  <p className="font-bold">{c.title}</p>
                  <p className="text-sm text-white/50">
                    {c.status} · {c.entry_price_coins} coins · {c.draw_mode}
                  </p>
                </div>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() =>
                      setEditCampaign({
                        ...c,
                        starts_at: c.starts_at?.slice(0, 16),
                        ends_at: c.ends_at?.slice(0, 16),
                      })
                    }
                    className="rounded-lg bg-white/10 px-3 py-1 text-xs"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={async () => {
                      if (!confirm("Delete campaign?")) return;
                      await deleteRupeeGameCampaign(c.id);
                      setCampaigns(campaigns.filter((x) => x.id !== c.id));
                      toast.success("Deleted");
                    }}
                    className="rounded-lg bg-red-500/20 px-3 py-1 text-xs text-red-300"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {tab === "prizes" && (
        <div className="space-y-4">
          <div className="flex flex-wrap gap-3 items-center">
            <select
              className="rounded-lg bg-black/40 border border-white/10 px-3 py-2"
              value={selectedCampaignId}
              onChange={(e) => {
                setSelectedCampaignId(e.target.value);
                void loadPrizes(e.target.value);
              }}
            >
              <option value="">Select campaign</option>
              {campaigns.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.title}
                </option>
              ))}
            </select>
            {selectedCampaignId && (
              <button
                type="button"
                onClick={() => setEditPrize(emptyPrize(selectedCampaignId))}
                className="flex items-center gap-2 rounded-xl bg-white/10 px-4 py-2 text-sm"
              >
                <Plus size={16} /> Add prize
              </button>
            )}
            <button
              type="button"
              onClick={() => selectedCampaignId && void loadPrizes(selectedCampaignId)}
              className="rounded-xl bg-white/5 p-2"
            >
              <RefreshCw size={14} />
            </button>
          </div>

          {editPrize && (
            <div className="glass-card p-6 space-y-4 border border-white/10">
              <div className="grid gap-4 md:grid-cols-2">
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Name</span>
                  <input
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editPrize.name}
                    onChange={(e) => setEditPrize({ ...editPrize, name: e.target.value })}
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Original value label</span>
                  <input
                    className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2"
                    value={editPrize.original_value_label}
                    onChange={(e) =>
                      setEditPrize({ ...editPrize, original_value_label: e.target.value })
                    }
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="text-white/50">Image</span>
                  <div className="flex items-center gap-2">
                    {editPrize.image_url ? (
                      <img src={editPrize.image_url} alt="" className="h-16 rounded" />
                    ) : null}
                    <label className="cursor-pointer rounded-lg bg-white/10 p-2">
                      {uploading ? (
                        <Loader2 className="animate-spin" size={14} />
                      ) : (
                        <Upload size={14} />
                      )}
                      <input
                        type="file"
                        className="hidden"
                        accept="image/*"
                        onChange={(e) => void handleImageUpload(e, "prize")}
                      />
                    </label>
                  </div>
                </label>
                <label className="flex items-center gap-2 text-sm pt-6">
                  <input
                    type="checkbox"
                    checked={!!editPrize.coming_soon}
                    onChange={(e) => setEditPrize({ ...editPrize, coming_soon: e.target.checked })}
                  />
                  <span className="text-white/70">Coming soon (hide Buy, show badge)</span>
                </label>
              </div>
              <button
                type="button"
                onClick={() => void handleSavePrize()}
                className="rounded-lg bg-emerald-500/30 px-4 py-2 text-sm text-emerald-200"
              >
                Save prize
              </button>
            </div>
          )}

          {loadingPrizes ? (
            <p className="text-white/50">Loading prizes…</p>
          ) : (
            <div className="grid gap-4">
              {prizes.map((p) => (
                <div key={p.id} className="glass-card p-4 border border-white/10 space-y-3">
                  <div className="flex justify-between gap-4">
                    <div className="flex gap-3">
                      {p.image_url ? (
                        <img
                          src={p.image_url}
                          alt=""
                          className="h-16 w-16 object-contain rounded"
                        />
                      ) : null}
                      <div>
                        <p className="font-bold">{p.name}</p>
                        <p className="text-sm text-white/50 line-through">
                          {p.original_value_label}
                        </p>
                        <p className="text-xs text-emerald-300">
                          {p.participant_count} participated
                        </p>
                        {p.coming_soon ? (
                          <p className="text-xs text-amber-300 font-semibold">Coming soon</p>
                        ) : null}
                        <p className="text-xs text-amber-300">
                          {p.draw_status}
                          {p.users?.username ? ` · Winner: ${p.users.username}` : ""}
                        </p>
                      </div>
                    </div>
                    <div className="flex flex-col gap-2 items-end">
                      <button
                        type="button"
                        onClick={() =>
                          setEditPrize({
                            id: p.id,
                            campaign_id: p.campaign_id,
                            name: p.name,
                            image_url: p.image_url ?? "",
                            original_value_label: p.original_value_label ?? "",
                            sort_order: p.sort_order ?? 0,
                            coming_soon: !!p.coming_soon,
                          })
                        }
                        className="text-xs text-sky-300"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={async () => {
                          await deleteRupeeGamePrize(p.id);
                          await loadPrizes(selectedCampaignId);
                        }}
                        className="text-red-300"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>
                  {p.draw_status === "pending" && (
                    <div className="flex flex-wrap gap-2 items-center">
                      <input
                        placeholder="Winner user ID (optional)"
                        className="rounded-lg bg-black/40 border border-white/10 px-3 py-1 text-xs flex-1 min-w-[200px]"
                        value={drawUserId[p.id] ?? ""}
                        onChange={(e) => setDrawUserId({ ...drawUserId, [p.id]: e.target.value })}
                      />
                      <button
                        type="button"
                        onClick={() => void handleDraw(p.id, false)}
                        className="rounded-lg bg-amber-500/20 px-3 py-1 text-xs text-amber-200"
                      >
                        Draw manual
                      </button>
                      <button
                        type="button"
                        onClick={() => void handleDraw(p.id, true)}
                        className="rounded-lg bg-violet-500/20 px-3 py-1 text-xs text-violet-200"
                      >
                        Draw random
                      </button>
                    </div>
                  )}
                  {p.draw_status === "drawn" && selectedCampaign?.refund_non_winners && (
                    <button
                      type="button"
                      onClick={() => void handleRefund(p.id)}
                      className="rounded-lg bg-sky-500/20 px-3 py-1 text-xs text-sky-200"
                    >
                      Refund losers
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === "entries" && (
        <div className="overflow-x-auto glass-card border border-white/10">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10 text-white/40 text-left">
                <th className="p-3">User</th>
                <th className="p-3">Campaign</th>
                <th className="p-3">Prize</th>
                <th className="p-3">Coins</th>
                <th className="p-3">Date</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((e) => (
                <tr key={e.id} className="border-b border-white/5">
                  <td className="p-3">{e.users?.username ?? e.user_id}</td>
                  <td className="p-3">{e.rupee_game_campaigns?.title ?? "—"}</td>
                  <td className="p-3">{e.rupee_game_prizes?.name ?? "—"}</td>
                  <td className="p-3">{e.coins_paid}</td>
                  <td className="p-3">{new Date(e.created_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {tab === "help" && (
        <div className="space-y-4">
          {helpSections.map((section, idx) => {
            const items: string[] = section.content?.items ?? [];
            return (
              <div key={section.id} className="glass-card p-4 border border-white/10 space-y-3">
                <input
                  className="w-full rounded-lg bg-black/40 border border-white/10 px-3 py-2 font-bold"
                  value={section.title}
                  onChange={(e) => {
                    const next = [...helpSections];
                    next[idx] = { ...section, title: e.target.value };
                    setHelpSections(next);
                  }}
                />
                <textarea
                  className="w-full min-h-[120px] rounded-lg bg-black/40 border border-white/10 px-3 py-2 text-sm"
                  value={items.join("\n")}
                  onChange={(e) => {
                    const next = [...helpSections];
                    next[idx] = {
                      ...section,
                      content: { items: e.target.value.split("\n").filter(Boolean) },
                    };
                    setHelpSections(next);
                  }}
                />
                <button
                  type="button"
                  onClick={() =>
                    void saveHelp({
                      id: helpSections[idx].id,
                      title: helpSections[idx].title,
                      content: helpSections[idx].content ?? { items: [] },
                      sort_order: helpSections[idx].sort_order,
                      is_expanded_default: helpSections[idx].is_expanded_default,
                    })
                  }
                  className="rounded-lg bg-emerald-500/30 px-4 py-2 text-sm text-emerald-200"
                >
                  Save section
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
