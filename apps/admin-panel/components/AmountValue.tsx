export function AmountValue({
  value,
  className = "",
  size = "md",
}: {
  value: string | number;
  className?: string;
  size?: "sm" | "md" | "lg" | "xl";
}) {
  const text = typeof value === "number" ? value.toLocaleString() : value;
  const digits = text.replace(/\D/g, "").length;
  const sizeClass =
    size === "xl"
      ? digits > 10
        ? "text-2xl sm:text-3xl"
        : digits > 7
          ? "text-3xl sm:text-4xl"
          : "text-4xl"
      : size === "lg"
        ? digits > 10
          ? "text-xl sm:text-2xl"
          : digits > 7
            ? "text-2xl"
            : "text-2xl sm:text-3xl"
        : size === "sm"
          ? digits > 10
            ? "text-sm"
            : "text-base"
          : digits > 10
            ? "text-base sm:text-lg"
            : digits > 7
              ? "text-lg sm:text-xl"
              : "text-xl sm:text-2xl";
  return (
    <p
      className={`font-black tabular-nums break-all leading-tight min-w-0 w-full ${sizeClass} ${className}`}
      title={text}
    >
      {text}
    </p>
  );
}
