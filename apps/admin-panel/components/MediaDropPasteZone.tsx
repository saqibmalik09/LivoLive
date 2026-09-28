"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { ClipboardPaste, ImagePlus, Loader2, Upload } from "lucide-react";
type Accent = "amber" | "blue";
function fileMatchesAccept(file: File, accept: string): boolean {
  if (!accept || accept === "*/*") return true;
  const parts = accept.split(",").map((p) => p.trim().toLowerCase());
  const name = file.name.toLowerCase();
  const type = (file.type || "").toLowerCase();
  return parts.some((p) => {
    if (p.startsWith(".")) return name.endsWith(p);
    if (p.endsWith("/*")) return type.startsWith(p.replace("/*", "/"));
    return type === p || name.endsWith(p);
  });
}
function fileFromClipboard(items: DataTransferItemList | undefined, accept: string): File | null {
  if (!items) return null;
  for (const item of Array.from(items)) {
    if (item.kind !== "file") continue;
    const file = item.getAsFile();
    if (file && fileMatchesAccept(file, accept)) return file;
  }
  for (const item of Array.from(items)) {
    if (item.type.startsWith("image/")) {
      const file = item.getAsFile();
      if (file) {
        if (fileMatchesAccept(file, accept)) return file;
        if (accept.includes("image")) {
          return new File([file], `paste-${Date.now()}.${file.type.split("/")[1] || "png"}`, {
            type: file.type,
          });
        }
      }
    }
  }
  return null;
}
interface MediaDropPasteZoneProps {
  accept?: string;
  label?: string;
  hint?: string;
  uploading?: boolean;
  disabled?: boolean;
  accent?: Accent;
  onFile: (file: File) => void | Promise<void>;
}
export function MediaDropPasteZone({
  accept = "image/*",
  label = "Drop image here",
  hint = "Drag & drop, paste (Ctrl/⌘ V), or browse",
  uploading = false,
  disabled = false,
  accent = "amber",
  onFile,
}: MediaDropPasteZoneProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const zoneRef = useRef<HTMLDivElement>(null);
  const [dragging, setDragging] = useState(false);
  const [focused, setFocused] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const accentBorder =
    accent === "blue" ? "border-blue-500/50 bg-blue-500/10" : "border-amber-500/50 bg-amber-500/10";
  const accentText = accent === "blue" ? "text-blue-400" : "text-amber-400";
  const handleFile = useCallback(
    async (file: File | null | undefined) => {
      if (!file || disabled || uploading) return;
      if (!fileMatchesAccept(file, accept)) {
        setError("File type not allowed");
        return;
      }
      setError(null);
      await onFile(file);
    },
    [accept, disabled, onFile, uploading],
  );
  useEffect(() => {
    function onPaste(e: ClipboardEvent) {
      if (disabled || uploading) return;
      const active = document.activeElement;
      const inTextField =
        active instanceof HTMLInputElement ||
        active instanceof HTMLTextAreaElement ||
        (active as HTMLElement | null)?.isContentEditable;
      const zoneActive =
        focused || zoneRef.current?.contains(active) || zoneRef.current?.matches(":hover");
      if (inTextField && !zoneRef.current?.contains(active)) return;
      if (!zoneActive && !zoneRef.current?.contains(active)) return;
      const file = fileFromClipboard(e.clipboardData?.items, accept);
      if (!file) return;
      e.preventDefault();
      void handleFile(file);
    }
    window.addEventListener("paste", onPaste);
    return () => window.removeEventListener("paste", onPaste);
  }, [accept, disabled, focused, handleFile, uploading]);
  return (
    <div
      ref={zoneRef}
      tabIndex={0}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      onDragEnter={(e) => {
        e.preventDefault();
        e.stopPropagation();
        if (!disabled) setDragging(true);
      }}
      onDragOver={(e) => {
        e.preventDefault();
        e.stopPropagation();
        if (!disabled) setDragging(true);
      }}
      onDragLeave={(e) => {
        e.preventDefault();
        e.stopPropagation();
        if (e.currentTarget === e.target) setDragging(false);
      }}
      onDrop={(e) => {
        e.preventDefault();
        e.stopPropagation();
        setDragging(false);
        const file = e.dataTransfer.files?.[0];
        void handleFile(file);
      }}
      onClick={() => {
        if (!disabled && !uploading) inputRef.current?.click();
      }}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          if (!disabled && !uploading) inputRef.current?.click();
        }
      }}
      className={`relative rounded-2xl border-2 border-dashed px-4 py-6 text-center cursor-pointer transition-all outline-none ${disabled ? "opacity-50 cursor-not-allowed" : ""} ${
        dragging || focused
          ? accentBorder
          : "border-white/15 bg-black/30 hover:border-white/30 hover:bg-black/40"
      }`}
    >
      <input
        ref={inputRef}
        type="file"
        className="hidden"
        accept={accept}
        disabled={disabled || uploading}
        onChange={(e) => {
          void handleFile(e.target.files?.[0]);
          e.target.value = "";
        }}
      />

      {uploading ? (
        <div className="flex flex-col items-center gap-2">
          <Loader2 size={28} className={`animate-spin ${accentText}`} />
          <p className="text-xs font-bold text-white/50">Uploading…</p>
        </div>
      ) : (
        <div className="flex flex-col items-center gap-2 pointer-events-none">
          <div className="flex items-center gap-3 text-white/40">
            <ImagePlus size={22} className={dragging ? accentText : ""} />
            <Upload size={18} />
            <ClipboardPaste size={18} />
          </div>
          <p className="text-sm font-bold text-white/80">{label}</p>
          <p className="text-[10px] uppercase tracking-widest font-black text-white/35">{hint}</p>
          {error && <p className="text-[11px] font-bold text-red-400 mt-1">{error}</p>}
        </div>
      )}
    </div>
  );
}
