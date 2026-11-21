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

echo "==> fetching $BRANCH"
git -C "$CLONE" fetch --prune origin
git -C "$CLONE" checkout "$BRANCH"
git -C "$CLONE" pull --ff-only origin "$BRANCH"
echo "==> clone now at $(git -C "$CLONE" rev-parse --short HEAD) on $BRANCH"

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

exec "$(dirname "$0")/deploy-service.sh" "$SERVICE"
