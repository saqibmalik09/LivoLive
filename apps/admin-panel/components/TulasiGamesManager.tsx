"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  updateTulasiGame,
  type TulasiGameRow,
  type TulasiTxnRow,
} from "@/app/settings/tulasi-games/actions";
import { TULASI_CALLBACK_BASE, TULASI_MERCHANT_ID } from "@/app/settings/tulasi-games/constants";
import type { RoomGameCategoryRow } from "@/app/settings/game-control/actions";
import { GameAudienceButton } from "@/components/GameAudiencePanel";
import { Check, Copy, Loader2, Save } from "lucide-react";
const TYPE_LABELS: Record<number, string> = {
  0: "Minus coin",
  1: "Add coin",
  2: "Minus gameCoin",
  3: "Add gameCoin",
};
export function TulasiGamesManager({
  games: initialGames,
  transactions,
  categories = [],
}: {
  games: TulasiGameRow[];
  transactions: TulasiTxnRow[];
  categories?: RoomGameCategoryRow[];
}) {
  const router = useRouter();
  const [games, setGames] = useState(initialGames);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [message, setMessage] = useState("");
  function patch(id: string, partial: Partial<TulasiGameRow>) {
    setGames((prev) => prev.map((g) => (g.id === id ? { ...g, ...partial } : g)));
  }
  async function copyBase() {
    try {
      await navigator.clipboard.writeText(TULASI_CALLBACK_BASE);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      setMessage("Copy failed");
    }
  }
  async function save(game: TulasiGameRow) {
    setSavingId(game.id);
    setMessage("");
    const res = await updateTulasiGame({
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
  return (
    <div className="space-y-10">
      <section className="glass-card border border-cyan-500/20 p-6 space-y-4">
        <h2 className="text-lg font-black text-cyan-300">Setup</h2>
        <p className="text-sm text-white/50">
          Merchant ID <span className="font-mono text-white/80">{TULASI_MERCHANT_ID}</span>. Set{" "}
          <code className="text-amber-300">TULASI_PLATFORM_PUBLIC_KEY</code>,{" "}
          <code className="text-amber-300">TULASI_MERCHANT_PRIVATE_KEY</code>, and{" "}
          <code className="text-amber-300">TULASI_MERCHANT_ID</code> in Supabase Edge Function
          secrets (never store PEMs in admin).
        </p>
        <div className="flex flex-wrap items-center gap-2">
          <code className="flex-1 min-w-[220px] text-xs bg-black/40 border border-white/10 rounded-xl px-3 py-2 break-all">
            {TULASI_CALLBACK_BASE}
          </code>
          <button
            type="button"
            onClick={copyBase}
            className="inline-flex items-center gap-2 px-3 py-2 rounded-xl border border-white/15 text-xs font-bold hover:bg-white/5"
          >
            {copied ? <Check size={14} /> : <Copy size={14} />}
            {copied ? "Copied" : "Copy"}
          </button>
        </div>
        <ul className="text-xs text-white/45 space-y-1 font-mono">
          <li>POST {TULASI_CALLBACK_BASE}userInformation</li>
          <li>POST {TULASI_CALLBACK_BASE}updateBalance</li>
          <li>POST {TULASI_CALLBACK_BASE}updateGameList</li>
        </ul>
      </section>

      {message && <p className="text-sm text-emerald-300 font-semibold">{message}</p>}

      <section className="space-y-4">
        <h2 className="text-lg font-black">Tulasi games ({games.length})</h2>
        {games.length === 0 ? (
          <div className="glass-card p-6 text-white/50 text-sm">
            No synced Tulasi games yet. After platform pushes{" "}
            <code className="text-amber-300">updateGameList</code>, rows appear here with{" "}
            <code>config_data.provider = tulasi</code>.
          </div>
        ) : (
          games.map((game) => (
            <article key={game.id} className="glass-card border border-white/10 p-5 space-y-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h3 className="font-black text-lg">{game.name}</h3>
                  <p className="text-xs text-white/40 font-mono mt-1">
                    {game.slug}
                    {game.tulasi_game_id ? ` · tulasi_id ${game.tulasi_game_id}` : ""}
                  </p>
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
                    title="Tulasi WebView orientation"
                  >
                    {game.is_landscape ? "LAND" : "PORT"}
                  </button>
                  <GameAudienceButton
                    scope="game_config"
                    targetId={game.id}
                    label={`Tulasi: ${game.name}`}
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
                  <input
                    className="mt-1 w-full bg-black/40 border border-white/10 rounded-xl px-3 py-2 text-sm font-mono"
                    value={game.icon_url ?? ""}
                    onChange={(e) => patch(game.id, { icon_url: e.target.value })}
                  />
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
                        webview_height_percent: Number(e.target.value) || 70,
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
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-cyan-400 text-black text-sm font-black disabled:opacity-50"
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

      <section className="space-y-4">
        <h2 className="text-lg font-black">Recent balance activity</h2>
        <div className="glass-card overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="text-xs uppercase tracking-wider text-white/40 border-b border-white/10">
              <tr>
                <th className="px-4 py-3">Time</th>
                <th className="px-4 py-3">User</th>
                <th className="px-4 py-3">Type</th>
                <th className="px-4 py-3">Coin</th>
                <th className="px-4 py-3">GameCoin</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Txn</th>
              </tr>
            </thead>
            <tbody>
              {transactions.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-white/40">
                    No Tulasi transactions yet.
                  </td>
                </tr>
              ) : (
                transactions.map((t) => (
                  <tr key={t.transaction_id} className="border-t border-white/5 text-white/80">
                    <td className="px-4 py-2 whitespace-nowrap text-xs text-white/50">
                      {t.created_at ? new Date(t.created_at).toLocaleString() : "—"}
                    </td>
                    <td className="px-4 py-2 font-mono text-xs">
                      {t.short_id ?? t.user_id.slice(0, 8)}
                    </td>
                    <td className="px-4 py-2 text-xs">{TYPE_LABELS[t.type] ?? `type ${t.type}`}</td>
                    <td className="px-4 py-2 font-mono text-xs">{t.coin}</td>
                    <td className="px-4 py-2 font-mono text-xs">{t.game_coin}</td>
                    <td className="px-4 py-2 text-xs">{t.status}</td>
                    <td className="px-4 py-2 font-mono text-[10px] text-white/40">
                      {t.transaction_id.length > 14
                        ? `${t.transaction_id.slice(0, 10)}…`
                        : t.transaction_id}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
