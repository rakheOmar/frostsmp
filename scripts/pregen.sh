#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename -- "$0") [diameter] [center-x] [center-z]

Pre-generate terrain using Chunky via RCON.

Arguments:
  diameter    Area diameter in blocks (default: 5000)
  center-x    Center X coordinate (default: 0)
  center-z    Center Z coordinate (default: 0)
EOF
  exit "${1:-0}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage 0
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

DIAMETER="${1:-5000}"
CENTER_X="${2:-0}"
CENTER_Z="${3:-0}"

if [[ ! "$DIAMETER" =~ ^[0-9]+$ ]] || [[ ! "$CENTER_X" =~ ^-?[0-9]+$ ]] || [[ ! "$CENTER_Z" =~ ^-?[0-9]+$ ]]; then
  log_error "All arguments must be integers"
  usage 1
fi

RADIUS=$((DIAMETER / 2))

log_info "Pre-generating terrain in a ${DIAMETER}x${DIAMETER} area around ($CENTER_X, $CENTER_Z)"
log_info "Server performance will degrade during generation"

rcon() {
  docker compose exec -T minecraft rcon "$@"
}

rcon "chunky radius $RADIUS"
rcon "chunky center $CENTER_X $CENTER_Z"
rcon "chunky start"

log_info "Chunky started"
printf 'Check progress:  docker compose exec -T minecraft rcon chunky progress\n'
printf 'Stop generation: docker compose exec -T minecraft rcon chunky pause\n'
