"use client";

import { useEffect, useCallback } from "react";
import { useParams } from "next/navigation";

export default function JoinRoomPage() {
  const params = useParams();
  const roomId =
    typeof params.roomId === "string" ? decodeURIComponent(params.roomId) : "";

  const openApp = useCallback(() => {
    if (!roomId) return;
    // Only custom scheme — intent:// often opens Play Store when verification is pending.
    window.location.href = `sklive://room/${roomId}`;
  }, [roomId]);

  useEffect(() => {
    openApp();
  }, [openApp]);

  if (!roomId) {
    return (
      <main className="min-h-screen flex flex-col items-center justify-center bg-[#1a0f08] text-white px-6">
        <h1 className="text-2xl font-bold font-[family-name:var(--font-outfit)]">
          SK Live
        </h1>
        <p className="mt-4 text-white/60">Invalid room link.</p>
      </main>
    );
  }

  return (
    <main className="min-h-screen flex flex-col items-center justify-center bg-[#1a0f08] text-white px-6 text-center">
      <h1 className="text-2xl font-bold font-[family-name:var(--font-outfit)]">
        SK Live
      </h1>
      <p className="mt-4 text-white/70">Opening your room…</p>
      <button
        type="button"
        onClick={openApp}
        className="mt-8 px-8 py-3 rounded-full bg-[#ffb300] text-[#1a0f08] font-bold hover:opacity-90 transition-opacity"
      >
        Open in App
      </button>
      <p className="mt-4 text-sm text-white/40">
        If nothing happens, tap the button above.
      </p>
    </main>
  );
}
