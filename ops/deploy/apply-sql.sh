#!/usr/bin/env bash
# Applies one SQL file to the live Supabase Postgres on vps1.
#
#   sudo ops/deploy/apply-sql.sh apps/mobile/supabase/migrations/<file>.sql
#
# Runs through psql with ON_ERROR_STOP and no wrapping transaction, so files
# containing CREATE INDEX CONCURRENTLY work. psql is autocommit per statement;
# files that need atomicity declare their own BEGIN/COMMIT.
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase-db-mnq3vesx0syflb0m0bot3oa2}"
FILE="${1:-}"

if [[ -z "$FILE" ]]; then
  echo "usage: $0 <path-to.sql>" >&2
  exit 2
fi
if [[ ! -f "$FILE" ]]; then
  echo "no such file: $FILE" >&2
  exit 2
fi
if ! docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER"; then
  echo "database container '$DB_CONTAINER' is not running" >&2
  echo "running containers:" >&2
  docker ps --format '  {{.Names}}' >&2
  exit 1
fi

echo "==> applying $(basename "$FILE") to $DB_CONTAINER"
START=$(date +%s)
docker exec -i "$DB_CONTAINER" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$FILE"
echo "==> done in $(( $(date +%s) - START ))s"
