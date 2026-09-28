import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Network, ScrollText } from "lucide-react";
import { getMasterOperatorDetail } from "../actions";
import { ADMIN_AUDIT_ACTION_LABELS } from "@/lib/admin-audit";
import { STAFF_ROLE_LABELS } from "@/lib/master-operator-tree";
function roleLabel(role: string) {
  return STAFF_ROLE_LABELS[role] || role;
}
function actionLabel(action: string) {
  return ADMIN_AUDIT_ACTION_LABELS[action] || action;
}
export default async function MasterOperatorTreePage({
  params,
}: {
  params: Promise<{
    id: string;
  }>;
}) {
  const { id } = await params;
  const res = await getMasterOperatorDetail(id);
  if (!res.success) notFound();
  const { operator, tree, recentAudit, unattributedAudit } = res;
  const t = tree.totals;
  return (
    <div className="space-y-10 pb-32 max-w-4xl">
      <Link
        href="/settings/master-panel"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">
          Master Panel operators
        </span>
      </Link>

      <header className="space-y-3">
        <div className="inline-flex p-3 bg-violet-500/20 rounded-2xl">
          <Network className="text-violet-300" size={28} />
        </div>
        <h1 className="text-4xl font-black tracking-tight">@{operator.username}</h1>
        <p className="text-white/50">
          App user {operator.users?.username ?? "—"} #{operator.users?.short_id ?? "—"} ·{" "}
          {operator.is_active ? "Active" : "Disabled"}
          {operator.last_login_at
            ? ` · Last login ${new Date(operator.last_login_at).toLocaleString()}`
            : ""}
        </p>
        <Link
          href={`/settings/activity-log?source=sklive-master-pannel&actor=mop:${operator.user_id}`}
          className="inline-flex items-center gap-2 text-sm text-violet-300 hover:text-violet-200"
        >
          <ScrollText size={14} />
          Activity log for this operator
        </Link>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: "Super Admins", value: t.superAdmins },
          { label: "BDs", value: t.bds },
          { label: "Agencies", value: t.agencies },
          { label: "Hosts", value: t.hosts },
          { label: "County Admins", value: t.countyAdmins },
          { label: "Assistants", value: t.assistants },
          { label: "Customer Service", value: t.customerService },
          { label: "Direct creates", value: t.directStaff },
        ].map((card) => (
          <div key={card.label} className="glass-card !p-4">
            <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
              {card.label}
            </p>
            <p className="text-3xl font-black mt-1">{card.value}</p>
          </div>
        ))}
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-black uppercase tracking-widest text-white/60">
          Super Admin trees
        </h2>
        {tree.superAdmins.length === 0 && (
          <p className="text-white/40 text-sm glass-card p-6">
            Is operator ne abhi koi Super Admin create nahi kiya (ya created_by backfill pending
            hai). Naye creates Master Panel se attribution ke sath save honge.
          </p>
        )}
        {tree.superAdmins.map((branch) => (
          <div key={branch.staff.id} className="glass-card p-6 space-y-5">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="text-[10px] font-black uppercase tracking-widest text-amber-400">
                  Super Admin
                </p>
                <Link
                  href={`/staff/${branch.staff.id}`}
                  className="text-2xl font-black hover:text-amber-300"
                >
                  {branch.staff.user?.username ?? "—"}
                </Link>
                <p className="text-xs text-white/40">
                  #{branch.staff.user?.short_id ?? "—"} · {branch.staff.staff_code}
                  {!branch.staff.is_active ? " · inactive" : ""}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase text-white/60">
                  BD {branch.counts.bds}
                </span>
                <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase text-white/60">
                  Agencies {branch.counts.agencies}
                </span>
                <span className="px-2.5 py-1 rounded-lg bg-white/5 text-[10px] font-black uppercase text-white/60">
                  Hosts {branch.counts.hosts}
                </span>
              </div>
            </div>

            <div>
              <p className="text-[10px] font-black uppercase tracking-widest text-white/30 mb-2">
                Team under this Super Admin
              </p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                {branch.children.map((child) => (
                  <Link
                    key={child.id}
                    href={`/staff/${child.id}`}
                    className="rounded-xl bg-white/5 border border-white/5 px-4 py-3 hover:border-amber-500/30"
                  >
                    <p className="text-[10px] font-black uppercase text-amber-400/70">
                      {roleLabel(child.role)}
                    </p>
                    <p className="font-bold">{child.user?.username ?? "—"}</p>
                    <p className="text-xs text-white/40">
                      #{child.user?.short_id ?? "—"} · {child.staff_code}
                    </p>
                  </Link>
                ))}
                {branch.children.length === 0 && (
                  <p className="text-white/30 text-sm">No staff under this Super Admin yet.</p>
                )}
              </div>
            </div>

            {branch.agencies.length > 0 && (
              <div>
                <p className="text-[10px] font-black uppercase tracking-widest text-white/30 mb-2">
                  Agencies (via BDs)
                </p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                  {branch.agencies.slice(0, 40).map((agency) => (
                    <Link
                      key={agency.id}
                      href={`/agencies/${agency.id}`}
                      className="rounded-xl bg-white/5 border border-white/5 px-4 py-3 hover:border-violet-500/30"
                    >
                      <p className="font-bold">{agency.name}</p>
                      <p className="text-xs text-white/40">
                        Code {agency.agency_code}
                        {agency.sponsor_username ? ` · BD ${agency.sponsor_username}` : ""}
                      </p>
                    </Link>
                  ))}
                </div>
                {branch.agencies.length > 40 && (
                  <p className="text-xs text-white/30 mt-2">
                    +{branch.agencies.length - 40} more agencies
                  </p>
                )}
              </div>
            )}
          </div>
        ))}
      </section>

      {tree.otherDirect.length > 0 && (
        <section className="space-y-4">
          <h2 className="text-xl font-black uppercase tracking-widest text-white/60">
            Other direct creates
          </h2>
          <p className="text-sm text-white/40">
            Staff is operator ne banaye jo kisi uske Super Admin tree ke andar nahi dikhte (e.g.
            under another SA, or role without SA parent).
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {tree.otherDirect.map((s) => (
              <Link
                key={s.id}
                href={`/staff/${s.id}`}
                className="glass-card !p-4 hover:border-amber-500/30"
              >
                <p className="text-[10px] font-black uppercase text-amber-400/70">
                  {roleLabel(s.role)}
                </p>
                <p className="font-bold">{s.user?.username ?? "—"}</p>
                <p className="text-xs text-white/40">
                  #{s.user?.short_id ?? "—"} · {s.staff_code}
                </p>
              </Link>
            ))}
          </div>
        </section>
      )}

      <section className="space-y-4">
        <h2 className="text-xl font-black uppercase tracking-widest text-white/60">
          Recent activity (this operator)
        </h2>
        <div className="space-y-2">
          {recentAudit.length === 0 && (
            <p className="text-white/40 text-sm glass-card p-6">
              No attributed Master Panel audit rows yet for this operator.
            </p>
          )}
          {recentAudit.map((r: any) => (
            <div key={r.id} className="glass-card !p-4 flex justify-between gap-3">
              <div>
                <p className="font-bold">{actionLabel(r.action)}</p>
                <p className="text-sm text-white/60">{r.summary || "—"}</p>
              </div>
              <p className="text-[11px] text-white/30 shrink-0">
                {new Date(r.created_at).toLocaleString()}
              </p>
            </div>
          ))}
        </div>
      </section>

      {unattributedAudit.length > 0 && (
        <section className="space-y-4">
          <h2 className="text-xl font-black uppercase tracking-widest text-white/60">
            Unattributed Master Panel actions
          </h2>
          <p className="text-sm text-white/40">
            Older actions without actor_user_id (env login or pre-fix logs). Not merged into this
            operator&apos;s tree.
          </p>
          <div className="space-y-2">
            {unattributedAudit.map((r: any) => (
              <div key={r.id} className="glass-card !p-4 flex justify-between gap-3 opacity-80">
                <div>
                  <p className="font-bold">{actionLabel(r.action)}</p>
                  <p className="text-sm text-white/60">{r.summary || "—"}</p>
                  <p className="text-[11px] text-white/30">{r.actor_label || "Master Panel"}</p>
                </div>
                <p className="text-[11px] text-white/30 shrink-0">
                  {new Date(r.created_at).toLocaleString()}
                </p>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
