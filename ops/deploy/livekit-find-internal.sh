#!/usr/bin/env bash
# Finds an address the gateway container can use to reach LiveKit directly
# (instead of the public proxy) and times each candidate. Read-only.
#
#   ops/deploy/livekit-find-internal.sh [gateway-container]
set -uo pipefail
GW="${1:-sklive-gateway}"
LK="$(docker ps --format '{{.Names}}' | grep -m1 -i '^livekit' || true)"
if [ -z "$LK" ]; then echo "no livekit container running"; exit 1; fi

echo "== livekit container: $LK"
echo "-- published ports"
docker port "$LK" || true
echo "-- livekit networks"
docker inspect "$LK" --format '{{range $n,$c := .NetworkSettings.Networks}}{{$n}} ip={{$c.IPAddress}}{{"\n"}}{{end}}'
echo "-- gateway networks"
docker inspect "$GW" --format '{{range $n,$c := .NetworkSettings.Networks}}{{$n}} ip={{$c.IPAddress}} gw={{$c.Gateway}}{{"\n"}}{{end}}'

CANDIDATES="http://172.17.0.1:7880 http://host.docker.internal:7880 http://127.0.0.1:7880"
for ip in $(docker inspect "$LK" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'); do
  CANDIDATES="$CANDIDATES http://$ip:7880"
done
for gw in $(docker inspect "$GW" --format '{{range .NetworkSettings.Networks}}{{.Gateway}} {{end}}'); do
  [ -n "$gw" ] && CANDIDATES="$CANDIDATES http://$gw:7880"
done
CANDIDATES="$CANDIDATES http://$LK:7880"

echo
echo "== reachability from $GW (5 tries each, ms)"
docker exec -i -e CANDIDATES="$CANDIDATES" "$GW" node - <<'JS'
(async () => {
  const seen = new Set();
  for (const base of process.env.CANDIDATES.split(/\s+/).filter(Boolean)) {
    if (seen.has(base)) continue;
    seen.add(base);
    const out = [];
    for (let i = 0; i < 5; i++) {
      const t0 = Date.now();
      const c = new AbortController();
      const timer = setTimeout(() => c.abort(), 2000);
      try {
        const r = await fetch(`${base}/`, { signal: c.signal });
        out.push(`${r.status}@${Date.now() - t0}`);
      } catch (e) {
        out.push(`ERR_${e.cause?.code || e.name}@${Date.now() - t0}`);
      } finally { clearTimeout(timer); }
    }
    console.log(base.padEnd(52), out.join(" "));
  }
})();
JS
