const PROJECT_REF = 'sklive';

/** Supabase auth cookies from other projects on shared localhost. */
export function isLegacyAuthCookie(name: string): boolean {
  if (!name.startsWith('sb-')) return false;
  return !name.includes(PROJECT_REF);
}
