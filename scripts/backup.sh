#!/usr/bin/env bash
# Archive the n8n and Qdrant volumes. Keeps 7 days.
# Containers are paused (not stopped) for the few seconds the archive takes,
# so SQLite and Qdrant files are captured in a consistent state.
# Cron (as deploy, via `crontab -e`):
#   0 3 * * * /home/deploy/all-maker-context/scripts/backup.sh >> /home/deploy/backups/backup.log 2>&1
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/home/deploy/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"
cd "$PROJECT_DIR"

unpause() { docker compose unpause n8n qdrant >/dev/null 2>&1 || true; }
trap unpause EXIT

echo "$(date -Is) backup start"
docker compose pause n8n qdrant

for vol in n8n_data qdrant_data; do
  docker run --rm \
    -v "$vol":/source:ro \
    -v "$BACKUP_DIR":/backup \
    alpine:3.22 \
    tar czf "/backup/${vol}-${STAMP}.tar.gz" -C /source .
done

unpause
trap - EXIT

find "$BACKUP_DIR" -name '*.tar.gz' -mtime +"$((RETENTION_DAYS - 1))" -delete
echo "$(date -Is) backup done: ${STAMP}"
