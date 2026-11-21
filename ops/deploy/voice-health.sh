#!/usr/bin/env bash
# Voice and room health on vps1. Read-only: safe to run while live.
#
#   sudo ops/deploy/voice-health.sh [seconds]
set -euo pipefail

WINDOW="${1:-180}"
GW=sklive-gateway

echo "===== container resource use ====="
docker stats --no-stream \
  --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'

echo
echo "===== voice token mints (last ${WINDOW}s) ====="
# perm=updated     : LiveKit accepted the permission change
# perm=not_connected: user is not in the LiveKit room yet (normal on first join)
# perm=pending     : mint replied without waiting; the sync finished in the
#                    background. Expected for most mints after the change that
#                    stopped blocking the reply on the admin API.
# perm=error_*     : LiveKit unreachable — investigate
docker logs --since "${WINDOW}s" "$GW" 2>&1 \
  | grep -oE 'perm=[a-z0-9_]+' | sort | uniq -c | sort -rn || echo "(none)"

echo
echo "===== slowest mints (last ${WINDOW}s) ====="
docker logs --since "${WINDOW}s" "$GW" 2>&1 \
  | grep -oE '\(([0-9]+)ms\)' | tr -d '(ms)' | sort -rn | head -10 || echo "(none)"

echo
echo "===== late background permission syncs ====="
docker logs --since "${WINDOW}s" "$GW" 2>&1 \
  | grep -c 'perm sync late' || true

echo
echo "===== warnings (last ${WINDOW}s) ====="
docker logs --since "${WINDOW}s" "$GW" 2>&1 \
  | grep -E '\[(seats|presence|gift|gift_settle|voice:livekit)\]' \
  | grep -iE 'failed|skipped|timeout' | tail -20 || echo "(none)"
