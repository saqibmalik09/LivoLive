"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, Loader2, ShieldCheck, ShieldOff, Trash2 } from "lucide-react";
import { activateAgency, deactivateAgency, permanentlyDeleteAgency } from "./actions";
export function DeactivateAgencyPanel({
  agencyId,
  agencyName,
  agencyCode,
  hostCount,
  isActive,
}: {
  agencyId: string;
  agencyName: string;
  agencyCode: string;
  hostCount: number;
  isActive: boolean;
}) {
  const router = useRouter();
  const [openDeactivate, setOpenDeactivate] = useState(false);
  const [openActivate, setOpenActivate] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);
  const [confirmCode, setConfirmCode] = useState("");
  const [confirmPhrase, setConfirmPhrase] = useState("");
  const [pending, start] = useTransition();
  function onDeactivate() {
    if (confirmCode.trim().toLowerCase() !== agencyCode.trim().toLowerCase()) {
      alert("Type the exact agency code to confirm.");
      return;
    }
    if (
      !confirm(
        `Deactivate "${agencyName}"?\n\nThis will:\n• Mark agency inactive\n• Remove ${hostCount} host(s) from the agency\n• Reject pending join requests\n\nUser accounts and salary history stay intact.`,
      )
    ) {
      return;
    }
    start(async () => {
      const res = await deactivateAgency(agencyId, confirmCode);
      if (res.success) {
        setOpenDeactivate(false);
        setConfirmCode("");
        router.refresh();
      } else {
        alert(res.error || "Failed to deactivate agency");
      }
    });
  }
  function onActivate() {
    if (confirmCode.trim().toLowerCase() !== agencyCode.trim().toLowerCase()) {
      alert("Type the exact agency code to confirm.");
      return;
    }
    if (
      !confirm(
        `Activate "${agencyName}"?\n\nThis will mark the agency active again so it can appear in rankings and agency flows.\nPreviously removed hosts are not auto-restored — they must rejoin.`,
      )
    ) {
      return;
    }
    start(async () => {
      const res = await activateAgency(agencyId, confirmCode);
      if (res.success) {
        setOpenActivate(false);
        setConfirmCode("");
        router.refresh();
      } else {
        alert(res.error || "Failed to activate agency");
      }
    });
  }
  function onPermanentDelete() {
    if (confirmCode.trim().toLowerCase() !== agencyCode.trim().toLowerCase()) {
      alert("Type the exact agency code to confirm.");
      return;
    }
    if (confirmPhrase.trim() !== "DELETE") {
      alert("Type DELETE in capitals to confirm permanent delete.");
      return;
    }
    if (
      !confirm(
        `PERMANENTLY DELETE "${agencyName}"?\n\nThis cannot be undone.\n• Agency row is removed\n• Hosts removed from membership (accounts stay)\n• Agency rankings / settlements for this agency are removed\n• Owner & host user accounts are NOT deleted`,
      )
    ) {
      return;
    }
    start(async () => {
      const res = await permanentlyDeleteAgency(agencyId, confirmCode, confirmPhrase);
      if (res.success) {
        router.push("/agencies");
        router.refresh();
      } else {
        alert(res.error || "Failed to permanently delete agency");
      }
    });
  }
  return (
    <div className="space-y-4">
      {isActive ? (
        <div className="glass-card p-8 border-red-500/20 bg-red-500/5 space-y-5">
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div className="flex items-start gap-3">
              <AlertTriangle className="text-red-400 shrink-0 mt-0.5" size={22} />
              <div>
                <h3 className="text-lg font-black tracking-tight">Deactivate agency</h3>
                <p className="text-sm text-white/40 mt-1 max-w-xl">
                  Soft-delete: agency becomes inactive and hosts are removed from membership. User
                  accounts, coins, and salary history are not deleted.
                </p>
              </div>
            </div>
            {!openDeactivate && (
              <button
                type="button"
                onClick={() => {
                  setOpenDelete(false);
                  setOpenActivate(false);
                  setOpenDeactivate(true);
                  setConfirmCode("");
                  setConfirmPhrase("");
                }}
                className="rounded-xl bg-red-500/20 text-red-300 px-5 py-2.5 text-sm font-bold hover:bg-red-500/30 border border-red-500/20"
              >
                Deactivate agency
              </button>
            )}
          </div>

          {openDeactivate && (
            <div className="space-y-4 pt-2 border-t border-red-500/10">
              <p className="text-xs text-white/50">
                Type agency code{" "}
                <span className="font-mono text-red-300 font-bold">{agencyCode}</span> to confirm.
                This removes <span className="text-white font-bold">{hostCount}</span> host
                {hostCount === 1 ? "" : "s"}.
              </p>
              <input
                value={confirmCode}
                onChange={(e) => setConfirmCode(e.target.value)}
                placeholder="Agency code"
                autoComplete="off"
                className="w-full max-w-sm bg-black/40 border border-red-500/30 rounded-xl px-4 py-3 text-sm font-mono outline-none focus:border-red-400"
              />
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  onClick={onDeactivate}
                  disabled={pending || !confirmCode.trim()}
                  className="rounded-xl bg-red-500 text-black px-5 py-2.5 text-sm font-black hover:bg-red-400 disabled:opacity-50 inline-flex items-center gap-2"
                >
                  {pending ? <Loader2 className="animate-spin" size={16} /> : null}
                  Confirm deactivate
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setOpenDeactivate(false);
                    setConfirmCode("");
                  }}
                  disabled={pending}
                  className="rounded-xl px-5 py-2.5 text-sm font-bold text-white/40 hover:text-white disabled:opacity-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      ) : (
        <div className="glass-card p-8 border-emerald-500/20 bg-emerald-500/5 space-y-5">
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div className="flex items-start gap-3">
              <ShieldOff className="text-red-300 shrink-0 mt-0.5" size={22} />
              <div>
                <p className="font-black uppercase tracking-widest text-xs text-red-300">
                  Agency inactive
                </p>
                <h3 className="text-lg font-black tracking-tight mt-1">Activate agency</h3>
                <p className="text-sm text-white/40 mt-1 max-w-xl">
                  Soft-deactivated earlier. Activate to restore agency flows and rankings.
                  Previously removed hosts are not auto-restored — they must rejoin.
                </p>
              </div>
            </div>
            {!openActivate && (
              <button
                type="button"
                onClick={() => {
                  setOpenDelete(false);
                  setOpenDeactivate(false);
                  setOpenActivate(true);
                  setConfirmCode("");
                  setConfirmPhrase("");
                }}
                className="rounded-xl bg-emerald-500/20 text-emerald-300 px-5 py-2.5 text-sm font-bold hover:bg-emerald-500/30 border border-emerald-500/20 inline-flex items-center gap-2"
              >
                <ShieldCheck size={16} />
                Activate agency
              </button>
            )}
          </div>

          {openActivate && (
            <div className="space-y-4 pt-2 border-t border-emerald-500/10">
              <p className="text-xs text-white/50">
                Type agency code{" "}
                <span className="font-mono text-emerald-300 font-bold">{agencyCode}</span> to
                confirm activation.
              </p>
              <input
                value={confirmCode}
                onChange={(e) => setConfirmCode(e.target.value)}
                placeholder="Agency code"
                autoComplete="off"
                className="w-full max-w-sm bg-black/40 border border-emerald-500/30 rounded-xl px-4 py-3 text-sm font-mono outline-none focus:border-emerald-400"
              />
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  onClick={onActivate}
                  disabled={pending || !confirmCode.trim()}
                  className="rounded-xl bg-emerald-500 text-black px-5 py-2.5 text-sm font-black hover:bg-emerald-400 disabled:opacity-50 inline-flex items-center gap-2"
                >
                  {pending ? <Loader2 className="animate-spin" size={16} /> : null}
                  Confirm activate
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setOpenActivate(false);
                    setConfirmCode("");
                  }}
                  disabled={pending}
                  className="rounded-xl px-5 py-2.5 text-sm font-bold text-white/40 hover:text-white disabled:opacity-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      <div className="glass-card p-8 border-red-600/40 bg-red-950/40 space-y-5">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div className="flex items-start gap-3">
            <Trash2 className="text-red-500 shrink-0 mt-0.5" size={22} />
            <div>
              <h3 className="text-lg font-black tracking-tight text-red-200">
                Permanent delete agency
              </h3>
              <p className="text-sm text-white/40 mt-1 max-w-xl">
                Irreversible. Removes the agency and related agency records (memberships,
                applications, rankings, settlements for this agency). Owner and host{" "}
                <span className="text-white/70 font-bold">user accounts are kept</span>.
              </p>
            </div>
          </div>
          {!openDelete && (
            <button
              type="button"
              onClick={() => {
                setOpenDeactivate(false);
                setOpenActivate(false);
                setOpenDelete(true);
                setConfirmCode("");
                setConfirmPhrase("");
              }}
              className="rounded-xl bg-red-600 text-white px-5 py-2.5 text-sm font-black hover:bg-red-500 border border-red-400/30"
            >
              Permanent delete
            </button>
          )}
        </div>

        {openDelete && (
          <div className="space-y-4 pt-2 border-t border-red-500/20">
            <p className="text-xs text-white/50">
              1) Type agency code{" "}
              <span className="font-mono text-red-300 font-bold">{agencyCode}</span>
              <br />
              2) Type <span className="font-mono text-red-300 font-bold">DELETE</span> (capitals)
            </p>
            <input
              value={confirmCode}
              onChange={(e) => setConfirmCode(e.target.value)}
              placeholder="Agency code"
              autoComplete="off"
              className="w-full max-w-sm bg-black/40 border border-red-500/30 rounded-xl px-4 py-3 text-sm font-mono outline-none focus:border-red-400"
            />
            <input
              value={confirmPhrase}
              onChange={(e) => setConfirmPhrase(e.target.value)}
              placeholder="Type DELETE"
              autoComplete="off"
              className="w-full max-w-sm bg-black/40 border border-red-500/30 rounded-xl px-4 py-3 text-sm font-mono outline-none focus:border-red-400"
            />
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={onPermanentDelete}
                disabled={pending || !confirmCode.trim() || confirmPhrase !== "DELETE"}
                className="rounded-xl bg-red-600 text-white px-5 py-2.5 text-sm font-black hover:bg-red-500 disabled:opacity-50 inline-flex items-center gap-2"
              >
                {pending ? <Loader2 className="animate-spin" size={16} /> : null}
                Confirm permanent delete
              </button>
              <button
                type="button"
                onClick={() => {
                  setOpenDelete(false);
                  setConfirmCode("");
                  setConfirmPhrase("");
                }}
                disabled={pending}
                className="rounded-xl px-5 py-2.5 text-sm font-bold text-white/40 hover:text-white disabled:opacity-50"
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
