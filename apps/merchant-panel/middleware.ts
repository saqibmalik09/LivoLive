import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * Cheap redirect for unauthenticated browsing. This only checks that a
 * cookie is present — it cannot reach the database from middleware — so
 * real authentication happens in `getMerchantActor()`, which every page
 * and action calls. Never treat passing this gate as being signed in.
 */
export function middleware(request: NextRequest) {
  const hasCookie = Boolean(request.cookies.get("merchant_session"));
  const { pathname } = request.nextUrl;
  const isLogin = pathname === "/login";

  if (!hasCookie && !isLogin) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  if (hasCookie && isLogin) {
    return NextResponse.redirect(new URL("/", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
};
