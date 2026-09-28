import { supabaseAdmin } from "@/lib/supabase";
import { ADMIN_AUDIT_ACTION_LABELS } from "@/lib/admin-audit";
import Link from "next/link";
import { ArrowLeft, ScrollText } from "lucide-react";
const ACTION_FILTERS = [
  "all",
  "user.ban",
  "user.unban",
  "user.promote_super_bd",
  "user.promote_county_admin",
  "user.promote_assistant",
  "user.promote_customer_service",
  "user.promote_bd",
  "staff.deactivate",
  "agency.application_approve",
  "agency.application_reject",
  "agency.host_approve",
  "agency.host_reject",
  "agency.create",
  "agency.assign_host",
  "agency.transfer_host",
  "agency.change_sponsor",
  "user.currency_update",
  "user.vip_set",
  "user.inventory_grant",
  "withdrawal.process",
  "real_name.review",
  "master_panel.operator_create",
] as const;
const SOURCE_FILTERS = [
  "all",
  "sklive-admin",
  "sklive-super-admin",
  "sklive-flutter",
  "sklive-master-pannel",
] as const;
function sourceLabel(source: string) {
  switch (source) {
    case "sklive-admin":
      return "Admin panel";
    case "sklive-super-admin":
      return "Staff web";
    case "sklive-flutter":
      return "Mobile app";
    case "sklive-master-pannel":
      return "Master Panel";
    case "all":
      return "All sources";
    default:
      return source;
  }
}
function actionLabel(action: string) {
  return ADMIN_AUDIT_ACTION_LABELS[action] || action;
}
function buildHref(opts: { action: string; source: string; actor: string }) {
  const q = new URLSearchParams();
  if (opts.source !== "all") q.set("source", opts.source);
  if (opts.action !== "all") q.set("action", opts.action);
  if (opts.actor !== "all") q.set("actor", opts.actor);
  const s = q.toString();
  return s ? `/settings/activity-log?${s}` : "/settings/activity-log";
}
type SuperAdminRow = {
  id: string;
  staff_code: string;
  user_id: string;
  is_active: boolean;
  users: {
    username: string | null;
    short_id: number | null;
  } | null;
};
type MasterOpRow = {
  id: string;
  user_id: string;
  username: string;
  is_active: boolean;
  users: {
    username: string | null;
    short_id: number | null;
  } | null;
};
export default async function AdminActivityLogPage({
  searchParams,
}: {
  searchParams: Promise<{
    action?: string;
    source?: string;
    actor?: string;
  }>;
}) {
  const sp = await searchParams;
  const action = sp.action || "all";
  const source = sp.source || "all";
  const actor = sp.actor || "all";
  const { data: superAdminsRaw } = await supabaseAdmin
    .from("business_staff")
    .select("id, staff_code, user_id, is_active, users:user_id(username, short_id)")
    .eq("role", "super_bd")
    .order("is_active", { ascending: false })
    .order("created_at", { ascending: true });
  const superAdmins = (superAdminsRaw || []).map((row: any) => ({
    ...row,
    users: Array.isArray(row.users) ? (row.users[0] ?? null) : row.users,
  })) as SuperAdminRow[];
  const { data: masterOpsRaw } = await supabaseAdmin
    .from("master_panel_operators")
    .select("id, user_id, username, is_active, users:user_id(username, short_id)")
    .order("is_active", { ascending: false })
    .order("created_at", { ascending: true });
  const masterOps = (masterOpsRaw || []).map((row: any) => ({
    ...row,
    users: Array.isArray(row.users) ? (row.users[0] ?? null) : row.users,
  })) as MasterOpRow[];
  let query = supabaseAdmin
    .from("admin_audit_logs")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(200);
  if (action !== "all") query = query.eq("action", action);
  if (source !== "all") query = query.eq("source", source);
  if (actor === "platform") {
    query = query.is("actor_staff_id", null).is("actor_user_id", null);
  } else if (actor.startsWith("mop:")) {
    const mopUserId = actor.slice(4);
    query = query.eq("actor_user_id", mopUserId);
  } else if (actor !== "all") {
    query = query.eq("actor_staff_id", actor);
  }
  const { data: rows, error } = await query;
  if (error) console.error(error.message);
  const selectedAdmin =
    actor !== "all" && actor !== "platform" && !actor.startsWith("mop:")
      ? superAdmins.find((s) => s.id === actor)
      : null;
  const selectedMasterOp = actor.startsWith("mop:")
    ? masterOps.find((o) => o.user_id === actor.slice(4))
    : null;
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Settings</span>
      </Link>

      <div>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <ScrollText size={48} className="text-amber-400" />
          Admin Activity
        </h1>
        <p className="text-white/40 mt-2">
          Super Admin, Platform Admin, aur Master Panel operators ki activity filter karo
        </p>
        {selectedAdmin && (
          <p className="text-amber-300/80 mt-2 text-sm font-medium">
            Showing: {selectedAdmin.users?.username || "Super Admin"} · #
            {selectedAdmin.users?.short_id ?? "—"} · {selectedAdmin.staff_code}
          </p>
        )}
        {selectedMasterOp && (
          <p className="text-violet-300/80 mt-2 text-sm font-medium">
            Showing Master Panel: @{selectedMasterOp.username}
            {selectedMasterOp.users?.username ? ` · ${selectedMasterOp.users.username}` : ""}
          </p>
        )}
        {actor === "platform" && (
          <p className="text-amber-300/80 mt-2 text-sm font-medium">
            Showing: Platform Admin (admin panel, no staff login)
          </p>
        )}
      </div>

      <div>
        <p className="text-[10px] font-black uppercase tracking-widest text-white/30 mb-2">
          Super Admin
        </p>
        <div className="flex flex-wrap gap-2">
          <Link
            href={buildHref({ action, source, actor: "all" })}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest ${actor === "all" ? "bg-emerald-500 text-black" : "bg-white/5 text-white/50"}`}
          >
            All Super Admins
          </Link>
          <Link
            href={buildHref({ action, source, actor: "platform" })}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest ${actor === "platform" ? "bg-emerald-500 text-black" : "bg-white/5 text-white/50"}`}
          >
            Platform Admin
          </Link>
          {superAdmins.map((sa) => {
            const label = `${sa.users?.username || "Super Admin"} (#${sa.users?.short_id ?? "—"})`;
            const active = actor === sa.id;
            return (
              <Link
                key={sa.id}
                href={buildHref({ action, source, actor: sa.id })}
                className={`px-4 py-2 rounded-xl text-xs font-black tracking-wide ${active ? "bg-emerald-500 text-black" : "bg-white/5 text-white/50"}`}
                title={`${sa.staff_code}${sa.is_active ? "" : " · inactive"}`}
              >
                {label}
                {!sa.is_active ? " · off" : ""}
              </Link>
            );
          })}
        </div>
      </div>

      {masterOps.length > 0 && (
        <div>
          <p className="text-[10px] font-black uppercase tracking-widest text-white/30 mb-2">
            Master Panel operators
          </p>
          <div className="flex flex-wrap gap-2">
            {masterOps.map((op) => {
              const key = `mop:${op.user_id}`;
              const active = actor === key;
              return (
                <Link
                  key={op.id}
                  href={buildHref({ action, source, actor: key })}
                  className={`px-4 py-2 rounded-xl text-xs font-black tracking-wide ${active ? "bg-violet-500 text-black" : "bg-white/5 text-white/50"}`}
                >
                  @{op.username}
                  {!op.is_active ? " · off" : ""}
                </Link>
              );
            })}
          </div>
        </div>
      )}

      <div className="flex flex-wrap gap-2">
        {SOURCE_FILTERS.map((s) => {
          const active = source === s;
          return (
            <Link
              key={s}
              href={buildHref({ action, source: s, actor })}
              className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest ${active ? "bg-amber-500 text-black" : "bg-white/5 text-white/50"}`}
            >
              {sourceLabel(s)}
            </Link>
          );
        })}
      </div>

      <div className="flex flex-wrap gap-2">
        {ACTION_FILTERS.map((a) => {
          const active = action === a;
          return (
            <Link
              key={a}
              href={buildHref({ action: a, source, actor })}
              className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest ${active ? "bg-violet-500 text-black" : "bg-white/5 text-white/40"}`}
            >
              {a === "all" ? "All actions" : actionLabel(a)}
            </Link>
          );
        })}
      </div>

      <div className="space-y-2">
        {(rows || []).length === 0 ? (
          <div className="glass-card p-12 text-center text-white/40">
            No activity for this filter yet.
          </div>
        ) : (
          (rows || []).map((r: any) => {
            const targetHref =
              r.target_type === "user" && r.target_id
                ? `/users/${r.target_id}`
                : r.target_type === "staff" && r.target_id
                  ? `/staff/${r.target_id}`
                  : r.target_type === "agency" && r.target_id
                    ? `/agencies/${r.target_id}`
                    : null;
            const actorHref =
              r.actor_staff_id && r.actor_staff_id !== actor
                ? buildHref({ action: "all", source: "all", actor: r.actor_staff_id })
                : r.actor_user_id && `mop:${r.actor_user_id}` !== actor
                  ? buildHref({
                      action: "all",
                      source: "sklive-master-pannel",
                      actor: `mop:${r.actor_user_id}`,
                    })
                  : null;
            return (
              <div
                key={r.id}
                className="glass-card !p-4 flex flex-wrap items-start justify-between gap-3"
              >
                <div className="min-w-0 flex-1">
                  <p className="font-bold truncate">{actionLabel(r.action)}</p>
                  <p className="text-sm text-white/60 mt-1">{r.summary || "—"}</p>
                  <p className="text-[11px] text-white/30 mt-2">
                    By{" "}
                    {actorHref ? (
                      <Link href={actorHref} className="text-emerald-300/80 hover:text-emerald-200">
                        {r.actor_label || "Platform Admin"}
                      </Link>
                    ) : (
                      r.actor_label || "Platform Admin"
                    )}
                    {r.source ? ` · ${sourceLabel(r.source)}` : ""}
                    {r.success === false ? " · FAILED" : ""}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-[11px] text-white/30">
                    {new Date(r.created_at).toLocaleString()}
                  </p>
                  {targetHref && (
                    <Link
                      href={targetHref}
                      className="text-[10px] font-black uppercase tracking-widest text-violet-300"
                    >
                      Open target
                    </Link>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
