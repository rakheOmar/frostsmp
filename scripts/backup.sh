#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
cd "$PROJECT_ROOT"

log_info()  { printf '[%s] INFO:  %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_warn()  { printf '[%s] WARN:  %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

DRY_RUN="${DRY_RUN:-false}"
SERVER_STOPPED=false

cleanup() {
  if [[ "$SERVER_STOPPED" == "true" ]]; then
    log_warn "Script exiting — restarting server..."
    docker compose start minecraft 2>/dev/null || true
  fi
}

trap 'log_error "Script failed at line $LINENO"' ERR
trap 'cleanup' EXIT

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[DRY RUN] Would execute: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

source .env 2>/dev/null || {
  log_error ".env not found. Copy .env.example to .env and configure it."
  exit 1
}

BACKUP_DIR="backups"
WORLD_DIR="server/world"
TIMESTAMP=$(date +%Y-%m-%d-%H%M)
ARCHIVE="${BACKUP_DIR}/backup-${TIMESTAMP}.tar.zst"
RETENTION=3

if [[ ! -d "$WORLD_DIR" ]] || [[ -z "$(find "$WORLD_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  log_error "World directory $WORLD_DIR is empty or missing."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "=== FrostSMP Backup ==="

log_info "Stopping server to lock world writes..."
run_cmd docker compose stop minecraft --time 60
SERVER_STOPPED=true

log_info "Compressing world directory..."
run_cmd tar -cf - -C "$WORLD_DIR" . | run_cmd zstd -o "$ARCHIVE"
if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ ${PIPESTATUS[1]} -ne 0 ]]; then
  log_error "Backup compression failed."
  exit 1
fi

log_info "Starting server..."
run_cmd docker compose start minecraft
SERVER_STOPPED=false

log_info "Backup saved: $ARCHIVE"

log_info "Pruning old backups (keeping newest $RETENTION)..."
mapfile -t backups < <(ls -1t "$BACKUP_DIR"/backup-*.tar.zst 2>/dev/null || true)
if [[ ${#backups[@]} -gt $RETENTION ]]; then
  for old in "${backups[@]:$RETENTION}"; do
    run_cmd rm -f -- "$old"
    log_info "Pruned: $old"
  done
fi

echo ""
echo "=== Backup complete ==="
ls -lh "$ARCHIVE"
