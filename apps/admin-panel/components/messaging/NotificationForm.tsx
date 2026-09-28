"use client";
import { useState } from "react";
import { Send, Users, User, Bell, Loader2 } from "lucide-react";
import { sendSystemNotification } from "@/app/messages/actions";
export function NotificationForm() {
  const [loading, setLoading] = useState(false);
  const [targetType, setTargetType] = useState<"broadcast" | "specific">("broadcast");
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const formData = new FormData(e.currentTarget);
    const title = formData.get("title") as string;
    const content = formData.get("content") as string;
    const userId = formData.get("userId") as string;
    const res = await sendSystemNotification(
      title,
      content,
      targetType === "specific" ? userId : undefined,
    );
    if (res.success) {
      alert("Notification sent successfully!");
      (e.target as HTMLFormElement).reset();
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  return (
    <div className="glass-card max-w-2xl mx-auto">
      <div className="flex items-center gap-2 mb-8">
        <Bell className="text-blue-400" />
        <h3 className="text-xl font-bold">Broadcast Center</h3>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="flex gap-4 p-1 bg-black/40 rounded-2xl border border-white/5 w-fit">
          <button
            type="button"
            onClick={() => setTargetType("broadcast")}
            className={`flex items-center gap-2 px-6 py-2 rounded-xl text-xs font-bold transition-all ${targetType === "broadcast" ? "bg-blue-500 text-white shadow-lg shadow-blue-500/20" : "text-white/40 hover:text-white"}`}
          >
            <Users size={16} /> Broadcast
          </button>
          <button
            type="button"
            onClick={() => setTargetType("specific")}
            className={`flex items-center gap-2 px-6 py-2 rounded-xl text-xs font-bold transition-all ${targetType === "specific" ? "bg-blue-500 text-white shadow-lg shadow-blue-500/20" : "text-white/40 hover:text-white"}`}
          >
            <User size={16} /> Targeted
          </button>
        </div>

        <div className="space-y-4">
          {targetType === "specific" && (
            <div className="space-y-2">
              <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                User ID
              </label>
              <input
                required
                name="userId"
                placeholder="Enter User UUID..."
                className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-blue-500/50 transition-all"
              />
            </div>
          )}

          <div className="space-y-2">
            <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
              Title
            </label>
            <input
              required
              name="title"
              placeholder="Notification Title..."
              className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-blue-500/50 transition-all"
            />
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
              Content
            </label>
            <textarea
              required
              name="content"
              rows={4}
              placeholder="What do you want to tell your users?"
              className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-blue-500/50 transition-all resize-none"
            />
          </div>
        </div>

        <button
          disabled={loading}
          className="w-full py-4 bg-blue-600 hover:bg-blue-500 text-white font-black rounded-2xl transition-all flex items-center justify-center gap-3 disabled:opacity-50"
        >
          {loading ? <Loader2 size={20} className="animate-spin" /> : <Send size={20} />}
          {targetType === "broadcast" ? "Send to All Users" : "Send to User"}
        </button>
      </form>
    </div>
  );
}
