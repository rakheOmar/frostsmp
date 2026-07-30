#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename -- "$0") <backup-file>

Restore server world and config from a backup archive.
EOF
  exit "${1:-0}"
}

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

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage 0
fi

check_deps docker tar

BACKUP_FILE="$(realpath -- "$1")"
BACKUP_DIR="$(dirname -- "$BACKUP_FILE")"
BACKUP_NAME="$(basename -- "$BACKUP_FILE")"

if [[ ! -f "$BACKUP_FILE" ]]; then
  log_error "Backup not found: $BACKUP_FILE"
  printf 'Available backups:\n'
  ls -1 "$PROJECT_ROOT/backups/" 2>/dev/null || true
  exit 1
fi

log_info "Stopping server"
docker compose down

log_info "Removing current world and config"
rm -rf "$PROJECT_ROOT/server/world" "$PROJECT_ROOT/server/config"
mkdir -p "$PROJECT_ROOT/server/world" "$PROJECT_ROOT/server/config"

log_info "Extracting $BACKUP_NAME"
tar xzf "$BACKUP_FILE" -C "$PROJECT_ROOT"

log_info "Starting server"
docker compose up -d

log_info "Restore complete from $BACKUP_NAME"
