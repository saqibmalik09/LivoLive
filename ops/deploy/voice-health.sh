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
# Only the reply lines, so a background sync that finishes late is not counted
# a second time here.
#
# perm=updated     : LiveKit accepted the permission change
# perm=not_connected: user is not in the LiveKit room yet (normal on first join)
# perm=pending     : mint replied without waiting; the sync finished in the
#                    background. Expected for most mints after the change that
#                    stopped blocking the reply on the admin API.
# perm=error_*     : LiveKit unreachable while the caller was still waiting
MINTS=$(docker logs --since "${WINDOW}s" "$GW" 2>&1 | grep '\[voice:livekit\] ok' || true)
if [[ -n "$MINTS" ]]; then
  echo "total: $(printf '%s\n' "$MINTS" | wc -l)"
  printf '%s\n' "$MINTS" | grep -oE 'perm=[A-Za-z0-9_]+' | sort | uniq -c | sort -rn
else
  echo "(none)"
fi

echo
echo "===== how long callers waited (last ${WINDOW}s) ====="
# Should all be at or under LIVEKIT_PERM_SYNC_WAIT_MS (default 250). Anything
# near 2000 means the old blocking build is still running.
if [[ -n "$MINTS" ]]; then
  printf '%s\n' "$MINTS" | grep -oE '\(([0-9]+)ms\)' | tr -d '(ms)' \
    | sort -rn | head -10
else
  echo "(none)"
fi

echo
echo "===== late background permission syncs ====="
# These cost the caller nothing, but a rising count means LiveKit's admin API is
# slow or unreachable, so already-connected users fall back to a reconnect.
LATE=$(docker logs --since "${WINDOW}s" "$GW" 2>&1 | grep 'perm sync late' || true)
if [[ -n "$LATE" ]]; then
  echo "count: $(printf '%s\n' "$LATE" | wc -l)"
  printf '%s\n' "$LATE" | grep -oE 'perm=[A-Za-z0-9_]+' | sort | uniq -c | sort -rn
else
  echo "count: 0"
fi

echo
echo "===== warnings (last ${WINDOW}s) ====="
docker logs --since "${WINDOW}s" "$GW" 2>&1 \
  | grep -E '\[(seats|presence|gift|gift_settle|voice:livekit)\]' \
  | grep -iE 'failed|skipped|timeout' | tail -20 || echo "(none)"
