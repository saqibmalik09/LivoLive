#!/usr/bin/env bash
# Read-only capture of everything needed to plan the LiveKit networking fix
# (docs/runbooks/livekit-networking.md). Changes nothing. Run on vps1:
#
#   sudo bash ops/deploy/livekit-diagnose.sh
#
# Paste the whole output back.
set -uo pipefail

C=$(docker ps --format '{{.Names}}' | grep -m1 '^livekit' || true)
if [[ -z "$C" ]]; then
  echo "NO LIVEKIT CONTAINER RUNNING"; docker ps --format '{{.Names}}'; exit 1
fi
echo "=== container: $C"

echo "=== network mode / memory / cpu"
docker inspect "$C" --format 'network={{.HostConfig.NetworkMode}} mem={{.HostConfig.Memory}} nanocpus={{.HostConfig.NanoCpus}}'

echo "=== port bindings"
docker inspect "$C" --format '{{json .HostConfig.PortBindings}}'

echo "=== command and args"
docker inspect "$C" --format '{{json .Config.Cmd}} {{json .Config.Entrypoint}}'

echo "=== config file (if any)"
docker exec "$C" sh -c 'for f in /etc/livekit.yaml /livekit.yaml /config.yaml /etc/livekit/config.yaml; do
  if [ -f "$f" ]; then echo "FOUND $f"; sed -E "s/(secret|key)[^:]*: .*/\1: REDACTED/I" "$f"; fi
done' 2>/dev/null || echo "exec failed"

echo "=== LIVEKIT_* environment (keys redacted)"
docker inspect "$C" --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep -i -E '^livekit|^redis|rtc|external|node_ip' \
  | sed -E 's/(API[A-Za-z0-9]{3})[A-Za-z0-9]+/\1.../; s/(secret[s]?[:=]).*/\1REDACTED/I'

echo "=== mounts (where the config lives on the host)"
docker inspect "$C" --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'

echo "=== compose location"
ls -la /data/coolify/services/*/ 2>/dev/null | grep -i -B2 livekit || true
grep -rl --include='*.yml' --include='*.yaml' -i 'livekit' /data/coolify/services/ 2>/dev/null | head -5

echo "=== redis the SFU uses"
docker ps --format '{{.Names}} {{.Ports}}' | grep -i redis

echo "=== last 60 log lines mentioning ICE/candidates/errors"
docker logs --tail 2000 "$C" 2>&1 \
  | grep -i -E 'candidate|selected|external|node_ip|too old|error' | tail -60

echo "=== live stats"
docker stats --no-stream "$C"
