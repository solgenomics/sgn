#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/srv/breedbase/volume/weather/sync.log"
SCRIPT="/srv/deltabreed/breedbase-prod/sgn-refactor-prod/tools/weather/sync_weather.py"
DB_CONTAINER="${DB_CONTAINER:-breedbase_db}"

log() {
    local msg="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$LOG_FILE"
}

if [ ! -x "$SCRIPT" ]; then
    log "ERROR: weather sync script is missing or not executable: $SCRIPT"
    exit 1
fi

DB_HOST="${PGHOST:-}"
if [ -z "$DB_HOST" ]; then
    DB_HOST="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DB_CONTAINER" 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$DB_HOST" ]; then
    log "ERROR: could not resolve Docker IP for $DB_CONTAINER"
    exit 1
fi

DB_PASSWORD="${PGPASSWORD:-}"
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD="$(docker exec "$DB_CONTAINER" printenv POSTGRES_PASSWORD 2>/dev/null || true)"
fi
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD="postgres"
fi

export PGHOST="$DB_HOST"
export PGDATABASE="${PGDATABASE:-breedbase}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="$DB_PASSWORD"
export PYTHONUNBUFFERED=1

SYNC_DAYS="${WEATHER_SYNC_DAYS:-30}"
RETAIN_DAYS="${WEATHER_SYNC_RETAIN_DAYS:-730}"

log "=== Starting Weather Sync: days=$SYNC_DAYS retain=$RETAIN_DAYS db_host=$PGHOST ==="
set +e
python3 "$SCRIPT" --days "$SYNC_DAYS" --retain "$RETAIN_DAYS"
status=$?
set -e

if [ "$status" -eq 0 ]; then
    log "=== Weather Sync Complete ==="
else
    log "=== Weather Sync FAILED: status=$status ==="
fi

exit "$status"
