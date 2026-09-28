import { Suspense } from "react";
import { August14App } from "./august14-app";

export default function August14Page() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-dvh items-center justify-center bg-[#0A0618] text-white">
          Loading…
        </div>
      }
    >
      <August14App />
    </Suspense>
  );
}
