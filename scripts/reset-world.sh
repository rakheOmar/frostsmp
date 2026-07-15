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

echo "=== FrostSMP Reset World ==="

echo "WARNING: This will DELETE the current world and generate a new one."
echo "A timestamped backup will be saved first."
echo ""
read -rp "Are you sure? Type 'yes' to continue: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

log_info "Stopping server..."
run_cmd docker compose stop minecraft -t 60
SERVER_STOPPED=true

if [[ -d "$WORLD_DIR" ]] && [[ -n "$(find "$WORLD_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  ARCHIVE="${BACKUP_DIR}/pre-reset-${TIMESTAMP}.tar.zst"
  log_info "Backing up current world..."
  run_cmd mkdir -p "$BACKUP_DIR"
  run_cmd tar -cf - -C "$WORLD_DIR" . | run_cmd zstd -o "$ARCHIVE"
  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ ${PIPESTATUS[1]} -ne 0 ]]; then
    log_error "Backup failed — aborting reset."
    exit 1
  fi
  log_info "Backup saved: $ARCHIVE"
fi

log_info "Deleting old world..."
run_cmd rm -rf "$WORLD_DIR"
run_cmd mkdir -p "$WORLD_DIR"

log_info "Starting server — a fresh world will generate using the configured seed..."
run_cmd docker compose start minecraft
SERVER_STOPPED=false

echo ""
echo "=== World reset complete ==="
echo "New world will generate with seed: ${LEVEL_SEED:-<not set>}"
