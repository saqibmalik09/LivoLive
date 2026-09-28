import { isLegacyAuthCookie } from '@/lib/supabase/cookie-config';

/** Remove old Supabase auth cookies from other projects on shared localhost. */
export function clearLegacyAuthCookies() {
  if (typeof document === 'undefined') return 0;

  const names = document.cookie
    .split(';')
    .map((part) => part.split('=')[0]?.trim())
    .filter((name): name is string => !!name && isLegacyAuthCookie(name));

  const unique = [...new Set(names)];
  for (const name of unique) {
    document.cookie = `${name}=; Max-Age=0; path=/`;
    document.cookie = `${name}=; Max-Age=0; path=/; domain=localhost`;
  }
  return unique.length;
}
