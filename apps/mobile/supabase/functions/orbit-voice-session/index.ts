import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

/**
 * Issues Orbit Voice (LiveKit) join credentials for SK Live rooms.
 * Secrets: ORBIT_API_URL, ORBIT_TENANT_API_KEY, ORBIT_LIVEKIT_URL (optional override)
 * Does not remove Zego — only used when system_settings.voice_backend=orbit.
 *
 * Hardened:
 * - Publish is seat-gated on durable room_seats (never trust client open_mic/on_seat alone).
 * - Cached orbit_room_id is verified against this room's livekitRoom.
 * - leave_seat → Orbit /leave (revoke publish + free seat).
 * - Open-mic: /join awaited with retries BEFORE token mint.
 * - Listener (not on seat, mic off): token ONLY via livekitRoom name.
 */
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const FETCH_TIMEOUT_MS = 8000;
const SETTINGS_TTL_MS = 60_000;

const SETTINGS_KEYS = [
  'voice_backend',
  'orbit_api_url',
  'orbit_livekit_url',
  'orbit_tenant_api_key',
  'livekit_url',
  'livekit_api_key',
  'livekit_api_secret',
  'livekit_test_user_ids',
];

const LIVEKIT_TOKEN_TTL_SECONDS = 6 * 60 * 60;

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Mints a LiveKit join token with Web Crypto — no extra import, no cold-start
 * network fetch. Mirrors the gateway's src/livekit_voice.js exactly.
 */
async function signLiveKitToken(opts: {
  apiKey: string;
  apiSecret: string;
  identity: string;
  name: string;
  room: string;
  canPublish: boolean;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const enc = new TextEncoder();
  const segment = (o: unknown) => b64url(enc.encode(JSON.stringify(o)));
  const data =
    segment({ alg: 'HS256', typ: 'JWT' }) +
    '.' +
    segment({
      iss: opts.apiKey,
      sub: opts.identity,
      jti: `${opts.identity}-${now}`,
      nbf: now - 10,
      exp: now + LIVEKIT_TOKEN_TTL_SECONDS,
      name: opts.name,
      video: {
        roomJoin: true,
        room: opts.room,
        canPublish: opts.canPublish,
        canSubscribe: true,
        canPublishData: true,
      },
    });
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(opts.apiSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data));
  return `${data}.${b64url(new Uint8Array(sig))}`;
}

let settingsCache: Record<string, string> | null = null;
let settingsCacheAt = 0;

async function loadOrbitSettings(
  admin: ReturnType<typeof createClient>,
): Promise<Record<string, string>> {
  const now = Date.now();
  if (settingsCache && now - settingsCacheAt < SETTINGS_TTL_MS) {
    return settingsCache;
  }
  const { data: settingsRows } = await admin
    .from('system_settings')
    .select('key, value')
    .in('key', SETTINGS_KEYS);
  const settings = Object.fromEntries(
    (settingsRows || []).map((r: { key: string; value: string }) => [
      r.key,
      r.value,
    ]),
  );
  settingsCache = settings;
  settingsCacheAt = now;
  return settings;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }

  const t0 = Date.now();
  const timings: Record<string, number> = {};
  const mark = (name: string, startedAt: number) => {
    timings[name] = Date.now() - startedAt;
  };

  try {
    let t = Date.now();
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'missing_auth' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const userClient = createClient(supabaseUrl, anon, {
      global: { headers: { Authorization: authHeader } },
    });
    const admin = createClient(supabaseUrl, service);

    const { data: userData, error: userErr } = await userClient.auth.getUser();
    mark('auth_getUser_ms', t);
    if (userErr || !userData.user) {
      logTiming('unauthorized', timings, t0);
      return json({ error: 'unauthorized', timings }, 401);
    }

    t = Date.now();
    const body = await req.json().catch(() => ({}));
    const roomId = String(body.room_id || '').trim();
    const openMic = Boolean(body.open_mic);
    const onSeatClaim = Boolean(body.on_seat);
    const billingOnly = Boolean(body.billing_only);
    const leaveSeat = Boolean(body.leave_seat);
    const cachedOrbitRoomId = String(body.orbit_room_id || '').trim() || null;
    mark('parse_body_ms', t);
    if (!roomId) return json({ error: 'room_id_required', timings }, 400);

    t = Date.now();
    const settings = await loadOrbitSettings(admin);
    mark('settings_ms', t);

    // Allow-list lets specific accounts run on LiveKit while everyone else stays
    // on the current backend — so a new build can be tested against production
    // without moving live users onto an engine their app version lacks.
    const livekitTestIds = String(settings.livekit_test_user_ids || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const forcedLiveKit = livekitTestIds.includes(userData.user.id);
    const backend = forcedLiveKit ? 'livekit' : settings.voice_backend || 'zego';

    // Direct LiveKit: mint the token here, no Orbit middleman.
    if (backend === 'livekit') {
      const lkUrl =
        String(settings.livekit_url || '').trim() || Deno.env.get('LIVEKIT_URL') || '';
      const lkKey =
        String(settings.livekit_api_key || '').trim() ||
        Deno.env.get('LIVEKIT_API_KEY') ||
        '';
      const lkSecret =
        String(settings.livekit_api_secret || '').trim() ||
        Deno.env.get('LIVEKIT_API_SECRET') ||
        '';
      if (!lkUrl || !lkKey || !lkSecret) {
        logTiming('livekit_not_configured', timings, t0, { roomId, openMic });
        return json(
          {
            error: 'livekit_not_configured',
            detail:
              'Set livekit_url, livekit_api_key and livekit_api_secret in system_settings',
            timings,
          },
          503,
        );
      }

      t = Date.now();
      const [lkSeat, lkRoom] = await Promise.all([
        admin
          .from('room_seats')
          .select('seat_index')
          .eq('room_id', roomId)
          .eq('user_id', userData.user.id)
          .maybeSingle(),
        admin.from('rooms').select('id').eq('id', roomId).maybeSingle(),
      ]);
      mark('seat_lookup_ms', t);

      if (!lkRoom.data) {
        logTiming('room_not_found', timings, t0, { roomId, openMic });
        return json({ error: 'room_not_found', timings }, 404);
      }

      // Publish comes from the durable seat row only — never the client's claim.
      const lkOnSeat = Boolean(lkSeat.data);
      const lkRoomName = `sklive_${roomId.replace(/-/g, '')}`;

      t = Date.now();
      const token = await signLiveKitToken({
        apiKey: lkKey,
        apiSecret: lkSecret,
        identity: userData.user.id,
        name: String(body.name || userData.user.id),
        room: lkRoomName,
        canPublish: lkOnSeat,
      });
      mark('livekit_sign_ms', t);

      logTiming('livekit_ok', timings, t0, { roomId, openMic });
      return json({
        token,
        livekit_url: lkUrl,
        livekit_room: lkRoomName,
        orbit_room_id: lkRoomName,
        can_publish: lkOnSeat,
        role: lkOnSeat ? 'speaker' : 'listener',
        on_seat: lkOnSeat,
        backend: 'livekit',
        timings,
      });
    }

    if (backend !== 'orbit') {
      logTiming('backend_not_orbit', timings, t0, { roomId, openMic });
      return json({ error: 'voice_backend_not_orbit', timings }, 400);
    }

    // Prefer DB URLs so a stale Edge secret cannot pin phones to an old SFU IP.
    const orbitApi =
      String(settings.orbit_api_url || '').replace(/\/$/, '') ||
      Deno.env.get('ORBIT_API_URL')?.replace(/\/$/, '') ||
      '';
    const livekitUrl =
      String(settings.orbit_livekit_url || '') ||
      Deno.env.get('ORBIT_LIVEKIT_URL') ||
      '';
    // Prefer DB key (admin-managed) so a stale Edge secret cannot block voice.
    const tenantKey =
      String(settings.orbit_tenant_api_key || '').trim() ||
      Deno.env.get('ORBIT_TENANT_API_KEY') ||
      '';

    if (!orbitApi || !tenantKey || !livekitUrl) {
      logTiming('not_configured', timings, t0, { roomId, openMic });
      return json(
        {
          error: 'orbit_not_configured',
          detail:
            'Set ORBIT_API_URL, ORBIT_TENANT_API_KEY (or system_settings.orbit_tenant_api_key), ORBIT_LIVEKIT_URL',
          timings,
        },
        503,
      );
    }

    const headers = {
      'content-type': 'application/json',
      'x-api-key': tenantKey,
    };

    const livekitRoom = `sklive_${roomId.replace(/-/g, '')}`;
    // Start Orbit upsert in parallel with seat lookup when we likely need a room.
    const needsOrbitRoomEarly = openMic || onSeatClaim || leaveSeat;

    t = Date.now();
    const seatPromise = admin
      .from('room_seats')
      .select('seat_index')
      .eq('room_id', roomId)
      .eq('user_id', userData.user.id)
      .maybeSingle();
    const roomPromise = admin
      .from('rooms')
      .select('id')
      .eq('id', roomId)
      .maybeSingle();
    const upsertPromise =
      needsOrbitRoomEarly && !cachedOrbitRoomId
        ? fetchWithTimeout(`${orbitApi}/api/rooms`, {
            method: 'POST',
            headers,
            body: JSON.stringify({
              title: `SK ${roomId.slice(0, 8)}`,
              livekitRoom,
              maxSeats: 20,
              metadata: { sklive_room_id: roomId },
            }),
          })
        : null;

    const [{ data: seatRow }, { data: roomRow }] = await Promise.all([
      seatPromise,
      roomPromise,
    ]);
    mark('seat_lookup_ms', t);

    if (!roomRow) {
      logTiming('room_not_found', timings, t0, { roomId });
      return json({ error: 'room_not_found', timings }, 404);
    }

    // Publish is seat-gated on the durable room_seats row.
    // Client `open_mic` / bare `on_seat` must NEVER mint canPublish alone.
    let seat = seatRow;
    if (!seat && onSeatClaim) {
      // Sit→speak race: claim ack can beat the seat row by a beat.
      await new Promise((r) => setTimeout(r, 120));
      const { data: seatRetry } = await admin
        .from('room_seats')
        .select('seat_index')
        .eq('room_id', roomId)
        .eq('user_id', userData.user.id)
        .maybeSingle();
      seat = seatRetry;
      timings.seat_retry_ms = 120;
    }
    const onSeat = Boolean(seat);
    const canPublish = onSeat;
    const needsOrbitRoom = openMic || onSeat || leaveSeat;
    const path = leaveSeat
      ? 'leave_seat'
      : openMic
        ? 'open_mic'
        : onSeat
          ? 'seat_mute'
          : 'listener';

    let orbitRoomId: string | null = null;

    if (needsOrbitRoom) {
      if (cachedOrbitRoomId) {
        t = Date.now();
        const verified = await verifyOrbitRoomId(
          orbitApi,
          headers,
          cachedOrbitRoomId,
          livekitRoom,
          roomId,
        );
        mark('orbit_room_verify_ms', t);
        if (verified) {
          orbitRoomId = cachedOrbitRoomId;
          timings.orbit_room_upsert_ms = 0;
        } else {
          console.warn(
            '[orbit-voice-session] cached orbit_room_id rejected',
            cachedOrbitRoomId,
          );
        }
      }
      if (!orbitRoomId) {
        t = Date.now();
        const upsertRes = upsertPromise
          ? await upsertPromise
          : await fetchWithTimeout(`${orbitApi}/api/rooms`, {
              method: 'POST',
              headers,
              body: JSON.stringify({
                title: `SK ${roomId.slice(0, 8)}`,
                livekitRoom,
                maxSeats: 20,
                metadata: { sklive_room_id: roomId },
              }),
            });
        mark('orbit_room_upsert_ms', t);
        if (upsertRes.ok) {
          const created = await upsertRes.json();
          orbitRoomId = created.room?.id ?? null;
        } else {
          const detail = await upsertRes.text();
          console.warn('[orbit-voice-session] room upsert failed', detail);
          if (!detail.includes('rooms_livekit_room_key')) {
            logTiming('orbit_create_failed', timings, t0, { roomId, path });
            return json({ error: 'orbit_create_failed', detail, timings }, 502);
          }
          t = Date.now();
          orbitRoomId = await resolveOrbitRoomId(
            orbitApi,
            headers,
            livekitRoom,
          );
          mark('orbit_room_resolve_ms', t);
          if (!orbitRoomId) {
            logTiming('orbit_resolve_failed', timings, t0, { roomId, path });
            return json(
              { error: 'orbit_resolve_failed', detail, timings },
              502,
            );
          }
        }
      }
    }

    if (leaveSeat && orbitRoomId) {
      t = Date.now();
      const leaveRes = await fetchWithTimeout(
        `${orbitApi}/api/rooms/${orbitRoomId}/leave`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({ userId: userData.user.id }),
        },
      );
      mark('orbit_leave_ms', t);
      const leaveOk = leaveRes.ok;
      if (!leaveOk) {
        console.warn(
          '[orbit-voice-session] leave failed',
          await leaveRes.text(),
        );
      }
      if (billingOnly) {
        timings.total_ms = Date.now() - t0;
        logTiming(leaveOk ? 'ok' : 'leave_failed', timings, t0, {
          roomId,
          path,
          openMic,
          onSeat,
          leaveSeat: true,
          billingOnly: true,
        });
        return json(
          {
            backend: 'orbit',
            billing_only: true,
            leave_seat: true,
            leave_ok: leaveOk,
            orbit_room_id: orbitRoomId,
            can_publish: false,
            on_seat: false,
            timings,
          },
          leaveOk ? 200 : 502,
        );
      }
    }

    if (orbitRoomId && billingOnly && !openMic && !leaveSeat && onSeat) {
      void fetchWithTimeout(`${orbitApi}/api/rooms/${orbitRoomId}/seats`, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({
          userId: userData.user.id,
          isMuted: true,
        }),
      }).catch((err) => console.warn('[orbit-voice-session] mute bg', err));
      timings.orbit_seats_mute_ms = 0;
    }

    if (billingOnly) {
      let joinOk = true;
      if (orbitRoomId && openMic && canPublish) {
        t = Date.now();
        joinOk = await joinOrbitWithRetry(
          orbitApi,
          headers,
          orbitRoomId,
          userData.user.id,
        );
        mark('orbit_join_ms', t);
        if (!joinOk) {
          console.warn('[orbit-voice-session] billing join failed');
        }
      } else if (orbitRoomId && openMic && !canPublish) {
        joinOk = false;
        console.warn(
          '[orbit-voice-session] billing open_mic ignored — not on seat',
        );
      }
      timings.total_ms = Date.now() - t0;
      logTiming(joinOk ? 'ok' : 'billing_join_failed', timings, t0, {
        roomId,
        path,
        openMic,
        onSeat,
        onSeatClaim,
        billingOnly: true,
        needsOrbitRoom,
      });
      return json({
        backend: 'orbit',
        billing_only: true,
        join_ok: joinOk,
        orbit_room_id: orbitRoomId,
        can_publish: canPublish,
        on_seat: onSeat,
        timings,
      });
    }

    // Open-mic must claim/allowPublish BEFORE token mint when possible so the
    // LiveKit grant is already active when the client connects.
    if (orbitRoomId && openMic && canPublish) {
      t = Date.now();
      const joinOk = await joinOrbitWithRetry(
        orbitApi,
        headers,
        orbitRoomId,
        userData.user.id,
      );
      mark('orbit_join_ms', t);
      if (!joinOk) {
        logTiming('orbit_join_failed', timings, t0, { roomId, path });
        return json({ error: 'orbit_join_failed', timings }, 502);
      }
    }

    if (openMic && !canPublish) {
      logTiming('publish_denied_not_on_seat', timings, t0, {
        roomId,
        path,
        openMic,
        onSeat,
        onSeatClaim,
      });
      return json(
        {
          error: 'publish_denied_not_on_seat',
          can_publish: false,
          on_seat: false,
          timings,
        },
        403,
      );
    }

    const tokenBody = orbitRoomId
      ? {
          roomId: orbitRoomId,
          userId: userData.user.id,
          name: userData.user.email || userData.user.id,
          canPublish,
        }
      : {
          livekitRoom,
          userId: userData.user.id,
          name: userData.user.email || userData.user.id,
          canPublish,
        };

    t = Date.now();
    const tokenRes = await fetchWithTimeout(`${orbitApi}/api/token`, {
      method: 'POST',
      headers,
      body: JSON.stringify(tokenBody),
    });
    mark('orbit_token_ms', t);
    if (!tokenRes.ok) {
      logTiming('orbit_token_failed', timings, t0, { roomId, path });
      return json(
        { error: 'orbit_token_failed', detail: await tokenRes.text(), timings },
        502,
      );
    }
    const tokenPayload = await tokenRes.json();
    timings.total_ms = Date.now() - t0;
    logTiming('ok', timings, t0, {
      roomId,
      path,
      openMic,
      onSeat,
      onSeatClaim,
      billingOnly,
      needsOrbitRoom,
      canPublish,
    });

    return json({
      backend: 'orbit',
      token: tokenPayload.token,
      livekit_url: livekitUrl,
      livekit_room: tokenPayload.livekitRoom || livekitRoom,
      orbit_room_id: orbitRoomId,
      can_publish: Boolean(tokenPayload.canPublish ?? canPublish),
      on_seat: onSeat,
      timings,
    });
  } catch (e) {
    timings.total_ms = Date.now() - t0;
    console.error('[orbit-voice-session]', e, timings);
    return json({ error: 'internal', detail: String(e), timings }, 500);
  }
});

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs = FETCH_TIMEOUT_MS,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function joinOrbitWithRetry(
  orbitApi: string,
  headers: Record<string, string>,
  orbitRoomId: string,
  userId: string,
): Promise<boolean> {
  for (let attempt = 1; attempt <= 3; attempt++) {
    const joinRes = await fetchWithTimeout(
      `${orbitApi}/api/rooms/${orbitRoomId}/join`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({
          userId,
          openMic: true,
        }),
      },
    );
    if (joinRes.ok) return true;
    const detail = await joinRes.text();
    const retryable =
      joinRes.status === 409 ||
      detail.includes('seat_busy_retry') ||
      detail.includes('no_free_seat');
    console.warn(
      `[orbit-voice-session] join attempt ${attempt} status=${joinRes.status}`,
      detail,
    );
    if (!retryable || attempt === 3) return false;
    await new Promise((r) => setTimeout(r, 120 * attempt));
  }
  return false;
}

async function verifyOrbitRoomId(
  orbitApi: string,
  headers: Record<string, string>,
  orbitRoomId: string,
  livekitRoom: string,
  skRoomId: string,
): Promise<boolean> {
  try {
    const res = await fetchWithTimeout(`${orbitApi}/api/rooms/${orbitRoomId}`, {
      method: 'GET',
      headers,
    });
    if (!res.ok) return false;
    const payload = await res.json();
    const room = payload?.room ?? payload;
    const name = room?.livekitRoom ?? room?.livekit_room;
    if (typeof name === 'string' && name === livekitRoom) return true;
    const metaRoom =
      room?.metadata?.sklive_room_id ?? room?.metadata?.sk_room_id;
    if (metaRoom && String(metaRoom) === skRoomId) return true;
    if (
      metaRoom &&
      livekitRoom.includes(String(metaRoom).replace(/-/g, ''))
    ) {
      return true;
    }
    return false;
  } catch (e) {
    console.warn('[orbit-voice-session] verify room', e);
    return false;
  }
}

async function resolveOrbitRoomId(
  orbitApi: string,
  headers: Record<string, string>,
  livekitRoom: string,
): Promise<string | null> {
  try {
    const listRes = await fetchWithTimeout(
      `${orbitApi}/api/rooms?livekitRoom=${encodeURIComponent(livekitRoom)}`,
      { method: 'GET', headers },
    );
    if (!listRes.ok) return null;
    const payload = await listRes.json();
    const rooms = Array.isArray(payload)
      ? payload
      : Array.isArray(payload?.rooms)
        ? payload.rooms
        : payload?.room
          ? [payload.room]
          : [];
    for (const room of rooms) {
      if (
        room?.livekitRoom === livekitRoom ||
        room?.livekit_room === livekitRoom
      ) {
        return room.id ?? null;
      }
    }
    return rooms[0]?.id ?? null;
  } catch (e) {
    console.warn('[orbit-voice-session] resolve room', e);
    return null;
  }
}

function logTiming(
  status: string,
  timings: Record<string, number>,
  t0: number,
  extra: Record<string, unknown> = {},
) {
  timings.total_ms = timings.total_ms ?? Date.now() - t0;
  console.log(
    '[orbit-voice-session] timing',
    JSON.stringify({ status, ...extra, timings }),
  );
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'content-type': 'application/json' },
  });
}
