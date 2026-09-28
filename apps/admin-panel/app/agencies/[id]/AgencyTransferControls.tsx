"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeftRight, Loader2, Network, ShieldCheck } from "lucide-react";
import { transferAgencyToBd, transferHostToAgency } from "@/app/users/actions";
type BdOption = {
  id: string;
  staffCode: string;
  username: string;
  shortId: string | null;
};
type AgencyOption = {
  id: string;
  name: string;
  agencyCode: string | null;
};
type MemberOption = {
  userId: string;
  username: string;
};
function bdLabel(opt: BdOption) {
  const uid = opt.shortId ? ` · UID ${opt.shortId}` : "";
  return `${opt.username}${uid} · ${opt.staffCode}`;
}
export function AgencyTransferControls({
  agencyId,
  agencyName,
  currentSponsorStaffId,
  bdOptions,
  otherAgencies,
  members,
}: {
  agencyId: string;
  agencyName: string;
  currentSponsorStaffId: string | null;
  bdOptions: BdOption[];
  otherAgencies: AgencyOption[];
  members: MemberOption[];
}) {
  const router = useRouter();
  const [sponsorStaffId, setSponsorStaffId] = useState(currentSponsorStaffId ?? "");
  const [memberUserId, setMemberUserId] = useState("");
  const [toAgencyId, setToAgencyId] = useState("");
  const [loading, setLoading] = useState<"sponsor" | "host" | null>(null);
  const handleSponsorTransfer = async () => {
    const next = sponsorStaffId || null;
    if ((currentSponsorStaffId || null) === next) {
      alert("Select a different BD");
      return;
    }
    const label = next ? bdOptions.find((b) => b.id === next) : null;
    if (
      !confirm(
        next
          ? `Move "${agencyName}" under BD ${label ? bdLabel(label) : next}?`
          : `Remove BD sponsor from "${agencyName}"?`,
      )
    ) {
      return;
    }
    setLoading("sponsor");
    const res = await transferAgencyToBd(agencyId, next);
    if (!res.success) alert(`Error: ${res.error}`);
    else router.refresh();
    setLoading(null);
  };
  const handleHostTransfer = async () => {
    if (!memberUserId || !toAgencyId) {
      alert("Select host and destination agency");
      return;
    }
    const member = members.find((m) => m.userId === memberUserId);
    const dest = otherAgencies.find((a) => a.id === toAgencyId);
    if (
      !confirm(
        `Transfer @${member?.username ?? "host"} from "${agencyName}" to "${dest?.name ?? "agency"}"?`,
      )
    ) {
      return;
    }
    setLoading("host");
    const res = await transferHostToAgency(memberUserId, toAgencyId, agencyId);
    if (!res.success) alert(`Error: ${res.error}`);
    else {
      setMemberUserId("");
      setToAgencyId("");
      router.refresh();
    }
    setLoading(null);
  };
  return (
    <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
      <div className="glass-card p-8 space-y-5 border-cyan-500/20 bg-cyan-500/5">
        <div className="flex items-center justify-between gap-3">
          <h3 className="text-lg font-black flex items-center gap-3 uppercase tracking-tight">
            <ShieldCheck className="text-cyan-400" size={22} />
            Move Agency to BD
          </h3>
          {loading === "sponsor" && <Loader2 size={16} className="animate-spin text-cyan-400" />}
        </div>
        <p className="text-sm text-white/45">
          Agency ko kisi BD se nikal kar kisi aur BD ke neeche assign karein.
        </p>
        <label className="block space-y-1.5">
          <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
            Sponsor BD
          </span>
          <select
            value={sponsorStaffId}
            onChange={(e) => setSponsorStaffId(e.target.value)}
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-cyan-500/50"
          >
            <option value="">No BD sponsor</option>
            {bdOptions.map((opt) => (
              <option key={opt.id} value={opt.id}>
                {bdLabel(opt)}
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          disabled={loading !== null}
          onClick={handleSponsorTransfer}
          className="w-full py-4 rounded-2xl font-black text-xs uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-2 bg-cyan-500/10 text-cyan-300 border border-cyan-400/20 hover:bg-cyan-500 hover:text-black disabled:opacity-50"
        >
          <Network size={18} />
          Save BD Sponsor
        </button>
      </div>

      <div className="glass-card p-8 space-y-5 border-emerald-500/20 bg-emerald-500/5">
        <div className="flex items-center justify-between gap-3">
          <h3 className="text-lg font-black flex items-center gap-3 uppercase tracking-tight">
            <ArrowLeftRight className="text-emerald-400" size={22} />
            Transfer Host Out
          </h3>
          {loading === "host" && <Loader2 size={16} className="animate-spin text-emerald-400" />}
        </div>
        <p className="text-sm text-white/45">
          Is agency se host nikal kar kisi aur agency mein transfer karein.
        </p>
        <div className="grid grid-cols-1 gap-4">
          <label className="block space-y-1.5">
            <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
              Host
            </span>
            <select
              value={memberUserId}
              onChange={(e) => setMemberUserId(e.target.value)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-emerald-500/50"
            >
              <option value="">Select host…</option>
              {members.map((m) => (
                <option key={m.userId} value={m.userId}>
                  @{m.username}
                </option>
              ))}
            </select>
          </label>
          <label className="block space-y-1.5">
            <span className="text-[10px] font-bold uppercase tracking-widest text-white/40">
              Destination agency
            </span>
            <select
              value={toAgencyId}
              onChange={(e) => setToAgencyId(e.target.value)}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-emerald-500/50"
            >
              <option value="">Select agency…</option>
              {otherAgencies.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                  {a.agencyCode ? ` (${a.agencyCode})` : ""}
                </option>
              ))}
            </select>
          </label>
        </div>
        <button
          type="button"
          disabled={loading !== null || !memberUserId || !toAgencyId}
          onClick={handleHostTransfer}
          className="w-full py-4 rounded-2xl font-black text-xs uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-2 bg-emerald-500/10 text-emerald-300 border border-emerald-400/20 hover:bg-emerald-500 hover:text-black disabled:opacity-50"
        >
          <ArrowLeftRight size={18} />
          Transfer Host
        </button>
      </div>
    </div>
  );
}
