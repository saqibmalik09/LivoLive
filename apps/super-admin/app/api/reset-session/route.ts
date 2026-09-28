import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

/** Clears Supabase auth cookies when headers grew too large (HTTP 431). */
export async function GET(request: NextRequest) {
  const response = NextResponse.redirect(new URL('/login?cleared=1', request.url));

  for (const cookie of request.cookies.getAll()) {
    if (cookie.name.startsWith('sb-')) {
      response.cookies.set(cookie.name, '', { path: '/', maxAge: 0 });
    }
  }

  return response;
}
