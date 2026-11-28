#!/usr/bin/env bash
# Times the gateway -> LiveKit admin call (the one that grants/revokes publish)
# over one or two addresses, from inside the gateway container so it uses the
# same network path and credentials as production. Read-only: it only lists
# rooms and participants.
#
#   ops/deploy/livekit-admin-latency.sh [container] [iterations] [internal-url]
#
# Example comparing the public URL with an internal one:
#   ops/deploy/livekit-admin-latency.sh sklive-gateway 20 http://172.17.0.1:7880
set -euo pipefail
CONTAINER="${1:-sklive-gateway}"
N="${2:-20}"
INTERNAL="${3:-}"

docker exec -i -e N="$N" -e INTERNAL="$INTERNAL" "$CONTAINER" node - <<'JS'
const { SignJWT } = require("jose");
const orbit = require("/app/src/orbit_voice");
(async () => {
  const s = await orbit.loadOrbitSettings();
  const wsUrl = String(s.livekit_url || "").trim() || process.env.LIVEKIT_URL || "";
  const key = String(s.livekit_api_key || "").trim() || process.env.LIVEKIT_API_KEY || "";
  const secret = String(s.livekit_api_secret || "").trim() || process.env.LIVEKIT_API_SECRET || "";
  if (!wsUrl || !key || !secret) { console.log("LiveKit settings not found"); return; }
  const publicBase = wsUrl.replace(/^wss:/i, "https:").replace(/^ws:/i, "http:").replace(/\/$/, "");
  const bases = { public: publicBase };
  if (process.env.INTERNAL) bases.internal = process.env.INTERNAL.replace(/\/$/, "");
  const sign = (video) => {
    const now = Math.floor(Date.now() / 1e3);
    return new SignJWT({ video }).setProtectedHeader({ alg: "HS256" }).setIssuer(key).setSubject(key)
      .setNotBefore(now - 10).setExpirationTime(now + 60).sign(new TextEncoder().encode(secret));
  };
  async function call(base, method, body, video) {
    const t0 = Date.now();
    const c = new AbortController();
    const timer = setTimeout(() => c.abort(), 5000);
    try {
      const res = await fetch(`${base}/twirp/livekit.RoomService/${method}`, {
        method: "POST", signal: c.signal,
        headers: { Authorization: `Bearer ${await sign(video)}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const text = await res.text();
      return { ms: Date.now() - t0, status: res.status, text };
    } catch (e) {
      return { ms: Date.now() - t0, status: `ERR_${e.name}${e.cause ? ":" + (e.cause.code || e.cause.message) : ""}`, text: "" };
    } finally { clearTimeout(timer); }
  }
  const n = Number(process.env.N || 20);
  for (const [label, base] of Object.entries(bases)) {
    console.log(`\n=== ${label}: ${base}`);
    const rooms = await call(base, "ListRooms", {}, { roomList: true });
    let names = [];
    try { names = (JSON.parse(rooms.text).rooms || []).map((r) => r.name); } catch (_) {}
    console.log(`first ListRooms -> ${rooms.status} in ${rooms.ms}ms, live rooms: ${names.length}`);
    const out = [];
    for (let i = 0; i < n; i++) {
      const room = names.length ? names[i % names.length] : "sklive_probe";
      const r = await call(base, "ListParticipants", { room }, { roomAdmin: true, room });
      out.push(r.status === 200 || r.status === 404 ? r.ms : `${r.status}@${r.ms}`);
      await new Promise((x) => setTimeout(x, 300));
    }
    const nums = out.filter((v) => typeof v === "number").sort((a, b) => a - b);
    console.log("ms per call:", out.join(" "));
    if (nums.length) console.log(`p50=${nums[Math.floor(nums.length / 2)]}ms max=${nums[nums.length - 1]}ms failed=${out.length - nums.length}/${out.length}`);
  }
})();
JS
