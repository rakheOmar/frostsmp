#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename -- "$0") --confirm

Delete the current world and regenerate it on next server start.
Requires --confirm to run.
EOF
  exit "${1:-0}"
}

if [[ "${1:-}" != "--confirm" ]]; then
  log_error "This will permanently delete server/world/"
  log_error "Run with --confirm to proceed, or run scripts/backup.sh first"
  usage 1
fi

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

check_deps docker

WORLD_DIR="$PROJECT_ROOT/server/world"

if [[ ! -d "$WORLD_DIR" ]]; then
  log_info "World directory does not exist — nothing to reset"
  exit 0
fi

log_info "Stopping server"
docker compose down

log_info "Removing world data"
rm -rf "$WORLD_DIR"
mkdir -p "$WORLD_DIR"

log_info "Starting server"
docker compose up -d

log_info "World reset complete — new seed will generate on next login"
