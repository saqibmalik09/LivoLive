#!/usr/bin/env bash
# Rebuilds and restarts ONE live service on vps1, nothing else.
#
#   sudo ops/deploy/deploy-service.sh gateway
#   sudo ops/deploy/deploy-service.sh admin
#
# Deliberately per-service: a whole-box `docker compose up` would also restart
# Supabase and LiveKit, which are managed separately by Coolify and must not be
# touched by an app deploy.
set -euo pipefail

SERVICE="${1:-}"
VALID=(gateway admin super-admin master-panel merchant-panel events landing)

if [[ -z "$SERVICE" ]]; then
  echo "usage: $0 <${VALID[*]// /|}>" >&2
  exit 2
fi
if ! printf '%s\n' "${VALID[@]}" | grep -qx "$SERVICE"; then
  echo "unknown service '$SERVICE'. known: ${VALID[*]}" >&2
  exit 2
fi

DIR="/opt/sklive-${SERVICE}"
COMPOSE="${DIR}/docker-compose.coolify.yml"
CONTAINER="sklive-${SERVICE}"

[[ -d "$DIR" ]]       || { echo "missing $DIR" >&2; exit 1; }
[[ -f "$COMPOSE" ]]   || { echo "missing $COMPOSE" >&2; exit 1; }
[[ -f "$DIR/.env" ]]  || { echo "missing $DIR/.env" >&2; exit 1; }

cd "$DIR"

# Next.js builds choke on the macOS resource-fork files that ride along in
# copied trees.
find . -name '._*' -type f -delete 2>/dev/null || true

echo "==> building $SERVICE"
docker compose -f "$COMPOSE" --env-file .env build
echo "==> build exited 0"

echo "==> restarting $SERVICE"
docker compose -f "$COMPOSE" --env-file .env up -d

echo "==> waiting for $CONTAINER"
for _ in $(seq 1 30); do
  STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo missing)
  [[ "$STATUS" == "running" ]] && break
  sleep 2
done

STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo missing)
echo "==> $CONTAINER status=$STATUS"
if [[ "$STATUS" != "running" ]]; then
  echo "!! not running — last 60 log lines:" >&2
  docker logs --tail 60 "$CONTAINER" 2>&1 || true
  exit 1
fi

docker logs --tail 25 "$CONTAINER" 2>&1 || true
