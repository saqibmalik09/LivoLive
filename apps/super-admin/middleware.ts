import { type NextRequest } from 'next/server';
import { updateSession } from '@/lib/supabase/middleware';

export async function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: [
    /*
     * Skip login/auth/static — prevents oversized Cookie headers (HTTP 431)
     * when Supabase session refresh runs on every login page load.
     */
    '/((?!_next/static|_next/image|favicon.ico|login|auth|access-denied|api/reset-session|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
