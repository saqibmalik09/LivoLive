import { supabaseAdmin } from "@/lib/supabase";
import { SupportInterface } from "@/components/messaging/SupportInterface";
import { NotificationForm } from "@/components/messaging/NotificationForm";
import { MessageSquare, Bell } from "lucide-react";
interface MessagesPageProps {
  searchParams: Promise<{
    tab?: string;
  }>;
}
export default async function MessagesPage({ searchParams }: MessagesPageProps) {
  const { tab = "support" } = await searchParams;
  const { data: tickets } = await supabaseAdmin
    .from("support_messages")
    .select("*")
    .order("created_at", { ascending: false });
  return (
    <div className="space-y-12 pb-32">
      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-400 tracking-tighter">
          Messages Hub
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Manage support tickets and system-wide announcements
        </p>
      </header>

      <div className="flex gap-4 border-b border-white/5 pb-1">
        <TabLink
          label="Support Tickets"
          active={tab === "support"}
          href="/messages?tab=support"
          icon={MessageSquare}
          badge={tickets?.filter((t) => t.status === "pending").length}
        />
        <TabLink
          label="System Notifications"
          active={tab === "notifications"}
          href="/messages?tab=notifications"
          icon={Bell}
        />
      </div>

      <div className="mt-8">
        {tab === "support" ? (
          <SupportInterface initialTickets={tickets || []} />
        ) : (
          <NotificationForm />
        )}
      </div>
    </div>
  );
}
import Link from "next/link";
function TabLink({ label, active, href, icon: Icon, badge }: any) {
  return (
    <Link
      href={href}
      className={`flex items-center gap-2 px-6 py-4 relative transition-all ${active ? "text-white" : "text-white/40 hover:text-white/60"}`}
    >
      <Icon size={18} />
      <span className="text-xs font-bold uppercase tracking-widest">{label}</span>
      {badge !== undefined && badge > 0 && (
        <span className="bg-purple-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-md ml-1">
          {badge}
        </span>
      )}
      {active && (
        <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-blue-400 to-purple-400 rounded-full" />
      )}
    </Link>
  );
}
