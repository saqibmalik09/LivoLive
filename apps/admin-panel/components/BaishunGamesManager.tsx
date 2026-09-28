"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  addBaishunGame,
  rehostBaishunGameIcon,
  syncBaishunGamelist,
  updateBaishunGame,
  uploadBaishunGameIcon,
  type BaishunGameRow,
} from "@/app/settings/baishun-games/actions";
import type { RoomGameCategoryRow } from "@/app/settings/game-control/actions";
import { GameAudienceButton } from "@/components/GameAudiencePanel";
import { ImagePlus, Loader2, Plus, RefreshCw, Save, Upload } from "lucide-react";
export function BaishunGamesManager({
  games: initialGames,
  categories = [],
}: {
  games: BaishunGameRow[];
  categories?: RoomGameCategoryRow[];
}) {
  const router = useRouter();
  const [games, setGames] = useState(initialGames);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [uploadingId, setUploadingId] = useState<string | null>(null);
  const [syncing, setSyncing] = useState(false);
  const [adding, setAdding] = useState(false);
  const [message, setMessage] = useState("");
  const [filter, setFilter] = useState<"all" | "active" | "inactive">("all");
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  const [newGame, setNewGame] = useState({
    baishun_game_id: "",
    name: "",
    game_url: "",
    icon_url: "",
    is_active: false,
    is_landscape: false,
    category_id: "",
  });
  const newIconRef = useRef<HTMLInputElement | null>(null);
  function patch(id: string, partial: Partial<BaishunGameRow>) {
    setGames((prev) => prev.map((g) => (g.id === id ? { ...g, ...partial } : g)));
  }
  const visible = games.filter((g) => {
    if (filter === "active") return g.is_active;
    if (filter === "inactive") return !g.is_active;
    return true;
  });
  async function save(game: BaishunGameRow) {
    setSavingId(game.id);
    setMessage("");
    const res = await updateBaishunGame({
      id: game.id,
      name: game.name,
      is_active: game.is_active,
      maintenance_mode: game.maintenance_mode,
      maintenance_message: game.maintenance_message,
      icon_url: game.icon_url,
      game_url: game.game_url,
      sort_order: game.sort_order,
      webview_height_percent: game.webview_height_percent,
      is_landscape: game.is_landscape,
      category_id: game.category_id,
    });
    setSavingId(null);
    if (!res.success) {
      setMessage(res.error ?? "Save failed");
      return;
    }
    setMessage(`Saved ${game.name}`);
    router.refresh();
  }
  async function handleUpload(game: BaishunGameRow, file: File) {
    setUploadingId(game.id);
    setMessage("");
    const fd = new FormData();
    fd.append("file", file);
    fd.append("slug", game.slug);
    fd.append("gameId", game.id);
    const res = await uploadBaishunGameIcon(fd);
    setUploadingId(null);
    if (!res.success || !res.url) {
      setMessage(res.error ?? "Icon upload failed");
      return;
    }
    patch(game.id, { icon_url: res.url });
    setMessage(`Icon uploaded for ${game.name}`);
    router.refresh();
  }
  async function handleRehost(game: BaishunGameRow) {
    setUploadingId(game.id);
    setMessage("");
    const res = await rehostBaishunGameIcon({ id: game.id });
    setUploadingId(null);
    if (!res.success || !res.url) {
      setMessage(res.error ?? "Rehost failed");
      return;
    }
    patch(game.id, { icon_url: res.url });
    setMessage(`Icon rehosted on Coolify for ${game.name}`);
    router.refresh();
  }
  async function handleSync(forceRehostIcons = false) {
    setSyncing(true);
    setMessage("");
    const res = await syncBaishunGamelist({ forceRehostIcons });
    setSyncing(false);
    if (!res.success) {
      setMessage(res.error ?? "Sync failed");
      return;
    }
    const errHint = res.errors && res.errors.length ? ` · warnings: ${res.errors.join("; ")}` : "";
    setMessage(
      `Synced — inserted ${res.inserted}, updated ${res.updated}, icons ${res.iconsHosted}${errHint}`,
    );
    router.refresh();
  }
  async function handleAdd() {
    setAdding(true);
    setMessage("");
    const res = await addBaishunGame({
      baishun_game_id: Number(newGame.baishun_game_id),
      name: newGame.name,
      game_url: newGame.game_url,
      icon_url: newGame.icon_url || null,
      is_active: newGame.is_active,
      is_landscape: newGame.is_landscape,
      category_id: newGame.category_id || null,
    });
    setAdding(false);
    if (!res.success) {
      setMessage(res.error ?? "Add failed");
      return;
    }
    setMessage(`Added ${res.slug}`);
    setNewGame({
      baishun_game_id: "",
      name: "",
      game_url: "",
      icon_url: "",
      is_active: false,
      is_landscape: false,
      category_id: "",
    });
    router.refresh();
  }
  async function handleNewIconUpload(file: File) {
    const fd = new FormData();
    fd.append("file", file);
    fd.append("slug", `baishun_${newGame.baishun_game_id || randomSlug()}`);
    const res = await uploadBaishunGameIcon(fd);
    if (!res.success || !res.url) {
      setMessage(res.error ?? "Icon upload failed");
      return;
    }
    setNewGame((s) => ({ ...s, icon_url: res.url! }));
    setMessage("New game icon uploaded");
  }
  function randomSlug() {
    return `new_${Date.now().toString(36)}`;
  }
  return (
    <div className="space-y-10">
      <section className="glass-card border border-orange-500/20 p-6 space-y-4">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-lg font-black text-orange-300">Baishun sync</h2>
            <p className="text-sm text-white/50 mt-1 max-w-2xl">
              Pull games from Baishun gamelist. New rows stay inactive until you turn them on.
              Preview icons are converted to JPEG and stored on Coolify{" "}
              <code className="text-amber-300">game-icons</code>.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              disabled={syncing}
              onClick={() => void handleSync(false)}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-orange-400 text-black text-sm font-black disabled:opacity-50"
            >
              {syncing ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
              Sync gamelist
            </button>
            <button
              type="button"
              disabled={syncing}
              onClick={() => void handleSync(true)}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border border-white/15 text-sm font-bold hover:bg-white/5 disabled:opacity-50"
            >
              Sync + rehost icons
            </button>
          </div>
        </div>
      </section>

      <section className="glass-card border border-white/10 p-6 space-y-4">
        <h2 className="text-lg font-black flex items-center gap-2">
          <Plus size={18} /> Add Baishun game
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <label className="text-xs text-white/50">
            Baishun game ID
            <input
              type="number"
              className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm font-mono"
              value={newGame.baishun_game_id}
              onChange={(e) => setNewGame((s) => ({ ...s, baishun_game_id: e.target.value }))}
              placeholder="e.g. 1022"
            />
          </label>
          <label className="text-xs text-white/50">
            Display name
            <input
              className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm"
              value={newGame.name}
              onChange={(e) => setNewGame((s) => ({ ...s, name: e.target.value }))}
              placeholder="FishingStar"
            />
          </label>
          <label className="text-xs text-white/50 md:col-span-2">
            Game / download URL
            <input
              className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm font-mono"
              value={newGame.game_url}
              onChange={(e) => setNewGame((s) => ({ ...s, game_url: e.target.value }))}
              placeholder="https://…/web-mobile/index.html"
            />
          </label>
          <label className="text-xs text-white/50 md:col-span-2">
            Icon URL
            <div className="mt-1 flex gap-2">
              <input
                className="flex-1 bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm font-mono"
                value={newGame.icon_url}
                onChange={(e) => setNewGame((s) => ({ ...s, icon_url: e.target.value }))}
                placeholder="Upload or paste Coolify URL"
              />
              <button
                type="button"
                onClick={() => newIconRef.current?.click()}
                className="px-3 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10"
                title="Upload icon"
              >
                <Upload size={16} />
              </button>
              <input
                ref={newIconRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) void handleNewIconUpload(f);
                  e.target.value = "";
                }}
              />
            </div>
          </label>
          <label className="text-xs text-white/50">
            Room sheet category
            <select
              className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm"
              value={newGame.category_id}
              onChange={(e) => setNewGame((s) => ({ ...s, category_id: e.target.value }))}
            >
              <option value="">Uncategorized</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <div className="flex flex-wrap items-center gap-4 text-xs font-bold pt-6">
            <label className="inline-flex items-center gap-2">
              <input
                type="checkbox"
                checked={newGame.is_active}
                onChange={(e) => setNewGame((s) => ({ ...s, is_active: e.target.checked }))}
              />
              Active
            </label>
            <label className="inline-flex items-center gap-2">
              <input
                type="checkbox"
                checked={newGame.is_landscape}
                onChange={(e) => setNewGame((s) => ({ ...s, is_landscape: e.target.checked }))}
              />
              Landscape
            </label>
          </div>
        </div>
        {newGame.icon_url ? (
          <img
            src={newGame.icon_url}
            alt=""
            className="w-16 h-16 rounded-2xl object-cover border border-white/10"
          />
        ) : null}
        <button
          type="button"
          disabled={adding}
          onClick={() => void handleAdd()}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-orange-400 text-black text-sm font-black disabled:opacity-50"
        >
          {adding ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
          Add game
        </button>
      </section>

      {message && (
        <p className="text-sm text-emerald-300 font-semibold whitespace-pre-wrap">{message}</p>
      )}

      <section className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-lg font-black">
            Baishun games ({visible.length}/{games.length})
          </h2>
          <div className="flex gap-2">
            {(["all", "active", "inactive"] as const).map((f) => (
              <button
                key={f}
                type="button"
                onClick={() => setFilter(f)}
                className={`px-3 py-1 rounded-full text-xs font-black capitalize ${
                  filter === f ? "bg-orange-400 text-black" : "bg-white/5 text-white/60"
                }`}
              >
                {f}
              </button>
            ))}
          </div>
        </div>

        {visible.length === 0 ? (
          <div className="glass-card p-6 text-white/50 text-sm">
            No Baishun games yet. Sync from Baishun or add a game manually above.
          </div>
        ) : (
          visible.map((game) => (
            <article key={game.id} className="glass-card border border-white/10 p-5 space-y-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="flex items-center gap-4 min-w-0">
                  <div className="w-16 h-16 rounded-2xl bg-black/50 border border-white/10 overflow-hidden flex items-center justify-center shrink-0">
                    {game.icon_url ? (
                      <img
                        src={game.icon_url}
                        alt={game.name}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <ImagePlus className="text-white/30" size={22} />
                    )}
                  </div>
                  <div className="min-w-0">
                    <h3 className="font-black text-lg">{game.name}</h3>
                    <p className="text-xs text-white/40 font-mono mt-1 break-all">
                      {game.slug}
                      {game.baishun_game_id != null ? ` · id ${game.baishun_game_id}` : ""}
                    </p>
                  </div>
                </div>
                <div className="flex flex-wrap items-center gap-3 text-xs font-bold">
                  <label className="inline-flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={game.is_active}
                      onChange={(e) => patch(game.id, { is_active: e.target.checked })}
                    />
                    Active
                  </label>
                  <label className="inline-flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={game.maintenance_mode}
                      onChange={(e) => patch(game.id, { maintenance_mode: e.target.checked })}
                    />
                    Maintenance
                  </label>
                  <button
                    type="button"
                    onClick={() => patch(game.id, { is_landscape: !game.is_landscape })}
                    className={`px-3 py-1 rounded-full text-xs font-black ${
                      game.is_landscape
                        ? "bg-amber-500/20 text-amber-300"
                        : "bg-sky-500/20 text-sky-300"
                    }`}
                  >
                    {game.is_landscape ? "LAND" : "PORT"}
                  </button>
                  <GameAudienceButton
                    scope="game_config"
                    targetId={game.id}
                    label={`Baishun: ${game.name}`}
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <label className="text-xs text-white/50">
                  Name
                  <input
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm"
                    value={game.name}
                    onChange={(e) => patch(game.id, { name: e.target.value })}
                  />
                </label>
                <label className="text-xs text-white/50">
                  Sort
                  <input
                    type="number"
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm"
                    value={game.sort_order}
                    onChange={(e) =>
                      patch(game.id, {
                        sort_order: Number(e.target.value) || 0,
                      })
                    }
                  />
                </label>
                <label className="text-xs text-white/50 md:col-span-2">
                  Game URL
                  <input
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm font-mono"
                    value={game.game_url ?? ""}
                    onChange={(e) => patch(game.id, { game_url: e.target.value })}
                  />
                </label>
                <label className="text-xs text-white/50 md:col-span-2">
                  Icon URL
                  <div className="mt-1 flex gap-2">
                    <input
                      className="flex-1 bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm font-mono"
                      value={game.icon_url ?? ""}
                      onChange={(e) => patch(game.id, { icon_url: e.target.value })}
                    />
                    <button
                      type="button"
                      disabled={uploadingId === game.id}
                      onClick={() => fileRefs.current[game.id]?.click()}
                      className="px-3 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 disabled:opacity-50"
                      title="Upload icon"
                    >
                      {uploadingId === game.id ? (
                        <Loader2 size={16} className="animate-spin" />
                      ) : (
                        <Upload size={16} />
                      )}
                    </button>
                    <button
                      type="button"
                      disabled={uploadingId === game.id}
                      onClick={() => void handleRehost(game)}
                      className="px-3 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 text-xs font-bold disabled:opacity-50"
                      title="Download remote preview and store on Coolify"
                    >
                      Rehost
                    </button>
                    <input
                      type="file"
                      accept="image/*"
                      className="hidden"
                      ref={(el) => {
                        fileRefs.current[game.id] = el;
                      }}
                      onChange={(e) => {
                        const f = e.target.files?.[0];
                        if (f) void handleUpload(game, f);
                        e.target.value = "";
                      }}
                    />
                  </div>
                </label>
                <label className="text-xs text-white/50">
                  WebView height %
                  <input
                    type="number"
                    min={40}
                    max={95}
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm"
                    value={game.webview_height_percent}
                    onChange={(e) =>
                      patch(game.id, {
                        webview_height_percent: Number(e.target.value) || 95,
                      })
                    }
                  />
                </label>
                <label className="text-xs text-white/50">
                  Room sheet category
                  <select
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm"
                    value={game.category_id ?? ""}
                    onChange={(e) =>
                      patch(game.id, {
                        category_id: e.target.value || null,
                      })
                    }
                  >
                    <option value="">Uncategorized</option>
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </label>
              </div>

              <button
                type="button"
                disabled={savingId === game.id}
                onClick={() => void save(game)}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-orange-400 text-black text-sm font-black disabled:opacity-50"
              >
                {savingId === game.id ? (
                  <Loader2 size={16} className="animate-spin" />
                ) : (
                  <Save size={16} />
                )}
                Save
              </button>
            </article>
          ))
        )}
      </section>
    </div>
  );
}
