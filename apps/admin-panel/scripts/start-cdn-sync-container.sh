#!/usr/bin/env bash
# On the VPS: start / restart the background CDN sync container.
# Joins the Supabase Docker network and talks to Kong internally so
# hairpin to public https://api...:443 does not ECONNREFUSED mid-run.
set -euo pipefail
DIR="${1:-/home/sklive/cdn-sync}"
cd "$DIR"

KONG_NAME="${SUPABASE_KONG_CONTAINER:-supabase-kong-mnq3vesx0syflb0m0bot3oa2}"
NET="$(sudo docker inspect "$KONG_NAME" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' | awk 'NR==1{print;exit}')"
INTERNAL_API="http://${KONG_NAME}:8000"

if [[ -z "$NET" ]]; then
  echo "Could not resolve docker network for $KONG_NAME"
  exit 1
fi

echo "Using network=$NET"
echo "Using NEXT_PUBLIC_SUPABASE_URL=$INTERNAL_API"

sudo docker rm -f r2-cdn-sync 2>/dev/null || true
sudo docker run -d --name r2-cdn-sync --restart on-failure:3 \
  --network "$NET" \
  -v "$DIR:/work" -w /work \
  --env-file "$DIR/.env" \
  -e NEXT_PUBLIC_SUPABASE_URL="$INTERNAL_API" \
  -e R2_SYNC_CONCURRENCY="${R2_SYNC_CONCURRENCY:-8}" \
  node:20-bookworm \
  bash -lc "node sync-all-public-assets-to-r2.mjs 2>&1 | tee -a /work/r2-full-cdn-sync.log"

sleep 4
sudo docker ps --filter name=r2-cdn-sync --format 'table {{.Names}}\t{{.Status}}'
echo "--- log ---"
sudo docker logs --tail 40 r2-cdn-sync 2>&1 || true
echo
echo "Follow: sudo docker logs -f r2-cdn-sync"
