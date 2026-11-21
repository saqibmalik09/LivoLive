#!/usr/bin/env bash
# Pulls a branch into the clone at /opt/livolive, copies one service's files
# into its live folder, and rebuilds only that service.
#
#   sudo ops/deploy/update-from-git.sh gateway main
#
# The live folders under /opt/sklive-* are intentionally NOT git working
# copies. This script is the bridge: git controls /opt/livolive, and files are
# copied forward from there. Local secrets (.env, .env.coolify) always stay as
# they are on the server.
#
# Branch matters per service. The gateway ships from `main`. The Next.js panels
# must NOT: `production` carries the Cloudflare R2 uploads and the one-per-
# calendar-month salary period that `main` does not have. See
# docs/runbooks/live-room-performance.md.
set -euo pipefail

SERVICE="${1:-}"
BRANCH="${2:-production}"
CLONE="${CLONE:-/opt/livolive}"
VALID=(gateway admin super-admin master-panel merchant-panel events landing)

if [[ -z "$SERVICE" ]]; then
  echo "usage: $0 <${VALID[*]// /|}> [branch]" >&2
  exit 2
fi
if ! printf '%s\n' "${VALID[@]}" | grep -qx "$SERVICE"; then
  echo "unknown service '$SERVICE'. known: ${VALID[*]}" >&2
  exit 2
fi

# Repo path for each live folder.
case "$SERVICE" in
  gateway)        SRC="apps/gateway" ;;
  admin)          SRC="apps/admin-panel" ;;
  super-admin)    SRC="apps/super-admin" ;;
  master-panel)   SRC="apps/master-panel" ;;
  merchant-panel) SRC="apps/merchant-panel" ;;
  events)         SRC="apps/events" ;;
  landing)        SRC="apps/landing" ;;
esac

DEST="/opt/sklive-${SERVICE}"
[[ -d "$CLONE" ]] || { echo "missing clone at $CLONE" >&2; exit 1; }
[[ -d "$DEST" ]]  || { echo "missing live folder $DEST" >&2; exit 1; }

# A dirty clone makes `git pull` refuse, and because this script stops on the
# first failure that used to look like a deploy that had happened when nothing
# had been copied at all. Fail loudly instead, and say how to clear it.
if ! git -C "$CLONE" diff --quiet || ! git -C "$CLONE" diff --cached --quiet; then
  echo "!! $CLONE has local modifications, so the pull would be refused." >&2
  git -C "$CLONE" status --short >&2
  echo >&2
  echo "   Nothing has been deployed. Discard them and re-run:" >&2
  echo "     git -C $CLONE checkout -- ." >&2
  exit 1
fi

echo "==> fetching $BRANCH"
git -C "$CLONE" fetch --prune origin
git -C "$CLONE" checkout "$BRANCH"
git -C "$CLONE" pull --ff-only origin "$BRANCH"
HEAD_SHA=$(git -C "$CLONE" rev-parse --short HEAD)
echo "==> clone now at $HEAD_SHA on $BRANCH"

[[ -d "$CLONE/$SRC" ]] || { echo "missing $CLONE/$SRC" >&2; exit 1; }

echo "==> diff $CLONE/$SRC -> $DEST (before copying)"
diff -rq \
  --exclude='.env' --exclude='.env.coolify' --exclude='node_modules' \
  --exclude='.next' --exclude='next-env.d.ts' --exclude='tsconfig.tsbuildinfo' \
  --exclude='._*' \
  "$CLONE/$SRC" "$DEST" || true

read -r -p "copy these changes into $DEST and rebuild? [y/N] " REPLY
[[ "$REPLY" == "y" || "$REPLY" == "Y" ]] || { echo "aborted"; exit 0; }

STAMP=$(date +%Y%m%d-%H%M%S)
echo "==> backing up $DEST to ${DEST}.bak-${STAMP}"
cp -a "$DEST" "${DEST}.bak-${STAMP}"

echo "==> copying (secrets and build output preserved)"
rsync -a --delete \
  --exclude='.env' --exclude='.env.coolify' --exclude='node_modules' \
  --exclude='.next' --exclude='next-env.d.ts' --exclude='tsconfig.tsbuildinfo' \
  --exclude='._*' \
  "$CLONE/$SRC/" "$DEST/"

"$(dirname "$0")/deploy-service.sh" "$SERVICE"

# Prove the new code is actually inside the running container. A successful
# build that was never picked up looks identical to a real deploy otherwise.
if [[ "$SERVICE" == "gateway" ]]; then
  echo "==> verifying new gateway code is live"
  if docker exec "sklive-gateway" \
       grep -q 'PERMISSION_SYNC_WAIT_MS' /app/src/livekit_voice.js 2>/dev/null; then
    echo "==> OK: non-blocking voice mint is in the running container"
  else
    echo "!! the running container does NOT contain the expected change." >&2
    echo "   Check the build output above; the old image may still be in use." >&2
    exit 1
  fi
fi

echo "==> deployed $SERVICE from $BRANCH @ ${HEAD_SHA}"
