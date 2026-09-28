import { countryFlagImageUrl, normalizeCountryCode } from '@/lib/countryFlag';

interface CountryFlagProps {
  code?: string | null;
  size?: number;
  className?: string;
}

/** Renders a real flag image (works on Windows; emoji flags often show as PK/IN letters). */
export function CountryFlag({ code, size = 22, className = '' }: CountryFlagProps) {
  const iso = normalizeCountryCode(code);
  const src = countryFlagImageUrl(code, 80);

  if (!iso || !src) {
    return (
      <span
        className={`inline-flex items-center justify-center rounded-sm bg-white/10 text-white/40 shrink-0 ${className}`}
        style={{ width: size, height: Math.round(size * 0.72) }}
        title="Unknown country"
      >
        🌍
      </span>
    );
  }

  const height = Math.round(size * 0.72);

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      width={size}
      height={height}
      alt={`${iso} flag`}
      title={iso}
      loading="lazy"
      className={`inline-block rounded-sm object-cover border border-white/10 shrink-0 ${className}`}
    />
  );
}
