#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
FILENAME="frostsmp-${TIMESTAMP}.tar.gz"

check_deps() {
  local -a missing=()
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    exit 1
  fi
}

check_deps docker tar

mkdir -p "$BACKUP_DIR"

log_info "Flushing world to disk"
docker compose exec -T minecraft rcon save-off 2>/dev/null || log_info "save-off skipped (may already be off)"
docker compose exec -T minecraft rcon save-all 2>/dev/null || true
sleep 2

log_info "Creating backup: $FILENAME"
tar czf "$BACKUP_DIR/$FILENAME" \
  -C "$PROJECT_ROOT" \
  server/world \
  server/config

docker compose exec -T minecraft rcon save-on 2>/dev/null || true

log_info "Pruning backups older than $RETENTION_DAYS days"
find "$BACKUP_DIR" -maxdepth 1 -name "frostsmp-*.tar.gz" -type f -mtime "+$RETENTION_DAYS" -delete

log_info "Backup complete: $BACKUP_DIR/$FILENAME"
