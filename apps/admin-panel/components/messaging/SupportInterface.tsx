"use client";
import { useState } from "react";
import {
  MessageSquare,
  Clock,
  CheckCircle2,
  User,
  Send,
  Loader2,
  Image as ImageIcon,
} from "lucide-react";
import { replyToSupportTicket } from "@/app/messages/actions";
interface SupportTicket {
  id: string;
  user_id: string;
  subject: string;
  message: string;
  admin_reply: string | null;
  status: string;
  created_at: string;
  image_url: string | null;
}
export function SupportInterface({ initialTickets }: { initialTickets: SupportTicket[] }) {
  const [tickets, setTickets] = useState(initialTickets);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const selectedTicket = tickets.find((t) => t.id === selectedId);
  async function handleReply(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!selectedId) return;
    setLoading(true);
    const formData = new FormData(e.currentTarget);
    const reply = formData.get("reply") as string;
    const res = await replyToSupportTicket(selectedId, reply);
    if (res.success) {
      setTickets(
        tickets.map((t) =>
          t.id === selectedId ? { ...t, admin_reply: reply, status: "resolved" } : t,
        ),
      );
      (e.target as HTMLFormElement).reset();
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <div className="lg:col-span-1 space-y-4">
        <h3 className="text-[10px] font-black uppercase tracking-[0.2em] text-white/30 px-2">
          Open Tickets
        </h3>
        <div className="space-y-3">
          {tickets.map((ticket) => (
            <button
              key={ticket.id}
              onClick={() => setSelectedId(ticket.id)}
              className={`w-full text-left glass-card transition-all ${selectedId === ticket.id ? "border-purple-500/50 bg-purple-500/5" : "hover:bg-white/5"}`}
            >
              <div className="flex justify-between items-start mb-2">
                <span
                  className={`text-[9px] font-black uppercase px-2 py-0.5 rounded ${ticket.status === "pending" ? "bg-amber-500/10 text-amber-500" : "bg-emerald-500/10 text-emerald-500"}`}
                >
                  {ticket.status}
                </span>
                <span className="text-[9px] text-white/20 font-bold">
                  {new Date(ticket.created_at).toLocaleDateString()}
                </span>
              </div>
              <h4 className="font-bold text-sm truncate">{ticket.subject}</h4>
              <p className="text-xs text-white/40 truncate mt-1">ID: {ticket.user_id}</p>
            </button>
          ))}
          {tickets.length === 0 && (
            <div className="glass-card text-center py-12 text-white/20 italic text-sm">
              No tickets found
            </div>
          )}
        </div>
      </div>

      <div className="lg:col-span-2">
        {selectedTicket ? (
          <div className="glass-card flex flex-col h-full min-h-[500px]">
            <div className="border-b border-white/5 pb-6 mb-6">
              <div className="flex items-center gap-4 mb-4">
                <div className="w-12 h-12 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center">
                  <User size={24} className="text-purple-400" />
                </div>
                <div>
                  <h3 className="text-xl font-bold">{selectedTicket.subject}</h3>
                  <p className="text-xs text-white/40">From: {selectedTicket.user_id}</p>
                </div>
              </div>

              <div className="bg-black/40 rounded-2xl p-6 border border-white/5">
                <p className="text-white/80 leading-relaxed text-sm whitespace-pre-wrap">
                  {selectedTicket.message}
                </p>
                {selectedTicket.image_url && (
                  <div className="mt-4">
                    <a
                      href={selectedTicket.image_url}
                      target="_blank"
                      rel="noreferrer"
                      className="inline-flex items-center gap-2 text-xs text-purple-400 hover:underline"
                    >
                      <ImageIcon size={14} /> View Attachment
                    </a>
                  </div>
                )}
              </div>
            </div>

            <div className="flex-1 space-y-6">
              {selectedTicket.admin_reply && (
                <div className="space-y-2">
                  <span className="text-[10px] font-black uppercase text-emerald-500 tracking-widest flex items-center gap-2 px-1">
                    <CheckCircle2 size={12} /> Admin Reply
                  </span>
                  <div className="bg-emerald-500/5 border border-emerald-500/20 rounded-2xl p-6">
                    <p className="text-emerald-50/80 text-sm whitespace-pre-wrap">
                      {selectedTicket.admin_reply}
                    </p>
                  </div>
                </div>
              )}

              {selectedTicket.status === "pending" && (
                <form onSubmit={handleReply} className="space-y-4">
                  <div className="space-y-2">
                    <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                      Write Response
                    </label>
                    <textarea
                      required
                      name="reply"
                      rows={6}
                      placeholder="Type your response here..."
                      className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-purple-500/50 transition-all resize-none"
                    />
                  </div>
                  <button
                    disabled={loading}
                    className="w-full py-4 bg-purple-600 hover:bg-purple-500 text-white font-black rounded-2xl transition-all flex items-center justify-center gap-3 disabled:opacity-50"
                  >
                    {loading ? <Loader2 size={20} className="animate-spin" /> : <Send size={20} />}
                    Send Response & Resolve
                  </button>
                </form>
              )}
            </div>
          </div>
        ) : (
          <div className="glass-card flex flex-col items-center justify-center h-full min-h-[500px] text-white/20 gap-4">
            <div className="p-8 bg-white/5 rounded-full">
              <MessageSquare size={64} strokeWidth={1} />
            </div>
            <p className="font-medium">Select a ticket to view and reply</p>
          </div>
        )}
      </div>
    </div>
  );
}
