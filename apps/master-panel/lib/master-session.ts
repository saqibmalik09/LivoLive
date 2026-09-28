import { cookies } from 'next/headers';
import { supabaseAdmin } from '@/lib/supabase';

const COOKIE_NAME = 'master_session';

export type MasterActor = {
  /** App user id for DB operators; null for env bootstrap login */
  userId: string | null;
  operatorId: string | null;
  username: string;
  label: string;
};

/**
 * Resolve the logged-in Master Panel operator from the session cookie.
 * Cookie forms: `env:master` | `op:{operatorId}:{username}`
 */
export async function getMasterActor(): Promise<MasterActor> {
  const jar = await cookies();
  const raw = jar.get(COOKIE_NAME)?.value?.trim() || '';

  if (!raw) {
    return {
      userId: null,
      operatorId: null,
      username: 'unknown',
      label: 'Master Panel',
    };
  }

  if (raw === 'env:master') {
    return {
      userId: null,
      operatorId: null,
      username: 'master',
      label: 'Master Panel (env)',
    };
  }

  if (raw.startsWith('op:')) {
    const parts = raw.split(':');
    const operatorId = parts[1] || null;
    const usernameFromCookie = parts.slice(2).join(':') || 'operator';

    if (operatorId) {
      const { data: op } = await supabaseAdmin
        .from('master_panel_operators')
        .select('id, user_id, username, is_active')
        .eq('id', operatorId)
        .maybeSingle();

      if (op?.is_active) {
        return {
          userId: op.user_id,
          operatorId: op.id,
          username: op.username || usernameFromCookie,
          label: `Master Panel (@${op.username || usernameFromCookie})`,
        };
      }
    }

    return {
      userId: null,
      operatorId,
      username: usernameFromCookie,
      label: `Master Panel (@${usernameFromCookie})`,
    };
  }

  return {
    userId: null,
    operatorId: null,
    username: 'unknown',
    label: 'Master Panel',
  };
}
