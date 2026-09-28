import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, ShieldCheck } from "lucide-react";
import { supabaseAdmin } from "@/lib/supabase";
import { extractKycObjectPath } from "@/lib/kyc-storage";
import { reviewRealNameApplication } from "../actions";
async function signedKycUrl(raw: string | null | undefined): Promise<string | null> {
  const path = extractKycObjectPath(raw);
  if (!path) return null;
  const { data, error } = await supabaseAdmin.storage
    .from("real_name_kyc")
    .createSignedUrl(path, 600);
  if (error || !data?.signedUrl) {
    console.error("[kyc] signed url failed", path, error?.message);
    return null;
  }
  return data.signedUrl;
}
export default async function RealNameDetailPage({
  params,
}: {
  params:
    | Promise<{
        id: string;
      }>
    | {
        id: string;
      };
}) {
  const resolved = await Promise.resolve(params);
  const { data: app } = await supabaseAdmin
    .from("real_name_applications")
    .select("*, users:user_id(username, avatar_url, short_id, phone)")
    .eq("id", resolved.id)
    .maybeSingle();
  if (!app) notFound();
  const user = Array.isArray(app.users) ? app.users[0] : app.users;
  const mediaRaw = [
    ["External APP proof", app.proof_external_app_url],
    ["Work account proof", app.proof_work_account_url],
    ["Work results", app.proof_work_results_url],
    ["ID front", app.id_photo_front_url],
    ["ID back", app.id_photo_back_url],
  ] as const;
  const media = await Promise.all(
    mediaRaw.map(async ([label, raw]) => [label, await signedKycUrl(raw)] as const),
  );
  const videoUrl = await signedKycUrl(app.video_auth_url);
  return (
    <div className="space-y-8 pb-32">
      <Link
        href="/real-name"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white"
      >
        <ArrowLeft size={16} /> Back
      </Link>

      <header className="flex items-center gap-4">
        <div className="w-16 h-16 rounded-2xl bg-sky-500/20 flex items-center justify-center text-sky-300">
          <ShieldCheck size={32} />
        </div>
        <div>
          <h1 className="text-4xl font-black tracking-tighter">
            {app.legal_name || user?.username || "Application"}
          </h1>
          <p className="text-white/50 text-sm mt-1">
            @{user?.username} · ID {user?.short_id} · Status:{" "}
            <span className="text-amber-300 font-bold uppercase">{app.status}</span>
          </p>
        </div>
      </header>

      <section className="glass-card p-6 grid md:grid-cols-2 gap-4 text-sm">
        <Field label="Country" value={app.country} />
        <Field label="Telephone" value={app.telephone} />
        <Field label="WhatsApp" value={app.whatsapp} />
        <Field label="Age" value={app.age} />
        <Field label="Years of work" value={app.years_of_work} />
        <Field label="How know app" value={app.how_know_app} />
        <Field label="Document #" value={app.document_number} />
        <Field label="Address" value={app.residential_address} />
        <Field label="Deposit coins" value={app.deposit_coins} />
        <Field
          label="Steps"
          value={`1:${flag(app.step1_done)} 2:${flag(app.step2_done)} 3:${flag(app.step3_done)} 4:${flag(app.step4_done)} 5:${flag(app.step5_done)}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-bold">Media</h2>
        <p className="text-xs text-white/40">Signed URLs expire in 10 minutes.</p>
        <div className="grid md:grid-cols-3 gap-4">
          {media.map(([label, url]) => (
            <div key={label} className="glass-card overflow-hidden">
              <div className="aspect-video bg-black/40 flex items-center justify-center">
                {url ? (
                  <img src={url} alt={label} className="w-full h-full object-cover" />
                ) : (
                  <span className="text-white/30 text-xs">Missing</span>
                )}
              </div>
              <p className="p-3 text-xs text-white/50">{label}</p>
            </div>
          ))}
        </div>
        {videoUrl && (
          <div className="glass-card p-4">
            <p className="text-sm font-bold mb-2">Video auth</p>
            <video src={videoUrl} controls className="w-full max-w-xl rounded-xl" />
          </div>
        )}
      </section>

      {app.status === "pending" && (
        <section className="glass-card p-6 space-y-4">
          <h2 className="text-lg font-bold">Review</h2>
          <div className="flex flex-wrap gap-3">
            <form action={reviewRealNameApplication}>
              <input type="hidden" name="id" value={app.id} />
              <input type="hidden" name="approve" value="1" />
              <button className="rounded-xl bg-emerald-500 px-5 py-2.5 font-bold text-sm text-black">
                Approve
              </button>
            </form>
            <form action={reviewRealNameApplication} className="flex flex-wrap gap-2 items-center">
              <input type="hidden" name="id" value={app.id} />
              <input type="hidden" name="approve" value="0" />
              <input
                name="reject_reason"
                placeholder="Reject reason"
                className="rounded-xl bg-black/40 border border-white/10 px-3 py-2 text-sm"
              />
              <button className="rounded-xl bg-red-500/80 px-5 py-2.5 font-bold text-sm">
                Reject
              </button>
            </form>
          </div>
        </section>
      )}

      {app.reject_reason && (
        <p className="text-red-300 text-sm">Reject reason: {app.reject_reason}</p>
      )}
    </div>
  );
}
function flag(v: boolean) {
  return v ? "✓" : "✗";
}
function Field({ label, value }: { label: string; value: any }) {
  return (
    <div>
      <p className="text-[10px] uppercase tracking-widest text-white/40 font-bold">{label}</p>
      <p className="font-medium mt-1 break-words">{value ?? "—"}</p>
    </div>
  );
}
