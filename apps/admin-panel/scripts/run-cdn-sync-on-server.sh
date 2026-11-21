#!/usr/bin/env bash
# Install + start full origin→R2 CDN sync inside sklive-admin container (background).
# Safe to re-run: skips objects already on CDN.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$ROOT/sync-all-public-assets-to-r2.mjs"
CONTAINER="${CDN_SYNC_CONTAINER:-sklive-admin}"
REMOTE_DIR="/app/scripts"
LOG="/tmp/r2-full-cdn-sync.log"

if [[ ! -f "$SCRIPT" ]]; then
  echo "missing $SCRIPT"
  exit 1
fi

echo "==> copy script into $CONTAINER:$REMOTE_DIR/"
sudo docker exec "$CONTAINER" mkdir -p "$REMOTE_DIR"
sudo docker cp "$SCRIPT" "$CONTAINER:$REMOTE_DIR/sync-all-public-assets-to-r2.mjs"

# Stop previous sync if still running
OLD_PID="$(sudo docker exec "$CONTAINER" sh -c 'pgrep -f sync-all-public-assets-to-r2.mjs || true' | head -1 || true)"
if [[ -n "${OLD_PID:-}" ]]; then
  echo "==> stopping previous sync pid=$OLD_PID"
  sudo docker exec "$CONTAINER" sh -c "kill $OLD_PID || true"
  sleep 1
fi

echo "==> starting background sync (log: $CONTAINER:$LOG)"
sudo docker exec -d "$CONTAINER" sh -c \
  "cd /app && R2_SYNC_CONCURRENCY=\${R2_SYNC_CONCURRENCY:-8} \
   node scripts/sync-all-public-assets-to-r2.mjs >>$LOG 2>&1"

sleep 2
echo "==> process:"
sudo docker exec "$CONTAINER" sh -c 'pgrep -af sync-all-public-assets-to-r2.mjs || echo "(not found yet)"'
echo "==> log tail:"
sudo docker exec "$CONTAINER" sh -c "tail -n 30 $LOG 2>/dev/null || echo '(log empty)'"
echo
echo "Follow: sudo docker exec -it $CONTAINER tail -f $LOG"
