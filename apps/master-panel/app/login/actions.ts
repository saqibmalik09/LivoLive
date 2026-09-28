'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { supabaseAdmin } from '@/lib/supabase';
import {
  normalizeMasterUsername,
  verifyPassword,
} from '@/lib/master-password';

const COOKIE_NAME = 'master_session';
const COOKIE_MAX_AGE = 86400;

function setSessionCookie(value: string) {
  return cookies().then((jar) => {
    jar.set(COOKIE_NAME, value, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: COOKIE_MAX_AGE,
    });
  });
}

export async function loginAction(formData: FormData) {
  const usernameRaw = String(formData.get('username') ?? '');
  const password = String(formData.get('password') ?? '');
  const username = normalizeMasterUsername(usernameRaw);

  if (!username || !password) {
    return { success: false as const, error: 'Username and password required' };
  }

  // Emergency bootstrap: env password (username "master")
  const envPassword = process.env.MASTER_PANEL_PASSWORD;
  if (
    envPassword &&
    username === 'master' &&
    password === envPassword
  ) {
    await setSessionCookie('env:master');
    redirect('/');
  }

  const { data: op, error } = await supabaseAdmin
    .from('master_panel_operators')
    .select('id, user_id, username, password_hash, is_active')
    .eq('username', username)
    .maybeSingle();

  if (error) {
    console.error('[master login]', error.message);
    return { success: false as const, error: 'Login failed' };
  }

  if (!op || !op.is_active || !verifyPassword(password, op.password_hash)) {
    return { success: false as const, error: 'Invalid username or password' };
  }

  await supabaseAdmin
    .from('master_panel_operators')
    .update({
      last_login_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', op.id);

  await setSessionCookie(`op:${op.id}:${op.username}`);
  redirect('/');
}

export async function logoutAction() {
  const jar = await cookies();
  jar.delete(COOKIE_NAME);
  redirect('/login');
}
