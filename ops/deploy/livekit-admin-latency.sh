#!/usr/bin/env bash
# Times the gateway -> LiveKit admin call (the one that grants/revokes publish).
# Runs inside the gateway container so it uses the same network path, URL and
# credentials as production. Read-only: it only lists rooms and participants.
#
#   ops/deploy/livekit-admin-latency.sh [container] [iterations]
set -euo pipefail
CONTAINER="${1:-sklive-gateway}"
N="${2:-20}"

docker exec -i -e N="$N" "$CONTAINER" node - <<'JS'
const { SignJWT } = require("jose");
const url = String(process.env.LIVEKIT_URL || "").replace(/^wss:/i, "https:").replace(/^ws:/i, "http:").replace(/\/$/, "");
const key = process.env.LIVEKIT_API_KEY, secret = process.env.LIVEKIT_API_SECRET;
if (!url || !key || !secret) {
  console.log("LIVEKIT_URL / LIVEKIT_API_KEY / LIVEKIT_API_SECRET are not set in the container env;");
  console.log("the gateway reads them from the settings table instead. Set them for this test or tell me.");
  process.exit(0);
}
const sign = (video) => {
  const now = Math.floor(Date.now() / 1e3);
  return new SignJWT({ video }).setProtectedHeader({ alg: "HS256" }).setIssuer(key).setSubject(key)
    .setNotBefore(now - 10).setExpirationTime(now + 60).sign(new TextEncoder().encode(secret));
};
async function call(method, body, video) {
  const t0 = Date.now();
  const c = new AbortController();
  const timer = setTimeout(() => c.abort(), 5000);
  try {
    const res = await fetch(`${url}/twirp/livekit.RoomService/${method}`, {
      method: "POST", signal: c.signal,
      headers: { Authorization: `Bearer ${await sign(video)}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const text = await res.text();
    return { ms: Date.now() - t0, status: res.status, text };
  } catch (e) {
    return { ms: Date.now() - t0, status: `ERR_${e.name}`, text: "" };
  } finally { clearTimeout(timer); }
}
(async () => {
  console.log("url host:", new URL(url).host);
  const rooms = await call("ListRooms", {}, { roomList: true });
  console.log(`ListRooms -> ${rooms.status} in ${rooms.ms}ms`);
  let names = [];
  try { names = (JSON.parse(rooms.text).rooms || []).map((r) => r.name); } catch (_) {}
  console.log("live rooms:", names.length);
  const n = Number(process.env.N || 20);
  const stats = { ListRooms: [], ListParticipants: [] };
  for (let i = 0; i < n; i++) {
    const a = await call("ListRooms", {}, { roomList: true });
    stats.ListRooms.push(a.status === 200 ? a.ms : `${a.status}@${a.ms}`);
    if (names.length) {
      const room = names[i % names.length];
      const b = await call("ListParticipants", { room }, { roomAdmin: true, room });
      stats.ListParticipants.push(b.status === 200 ? b.ms : `${b.status}@${b.ms}`);
    }
    await new Promise((r) => setTimeout(r, 400));
  }
  console.log("ListRooms ms:       ", stats.ListRooms.join(" "));
  console.log("ListParticipants ms:", stats.ListParticipants.join(" "));
})();
JS
