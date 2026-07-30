#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename -- "$0") [--server]

Export the packwiz modpack as a Modrinth .mrpack file.

Options:
  --server    Include only server-side mods (for server pack)
  --help      Show this help message

Without --server, exports both client and server mods (default).
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

check_deps packwiz

SERVER_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      SERVER_ONLY=true
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage 1
      ;;
  esac
done

cd "$PROJECT_ROOT/packwiz"

log_info "Refreshing index"
packwiz refresh

if [[ "$SERVER_ONLY" == "true" ]]; then
  log_info "Exporting server-only pack"
  packwiz modrinth export --side server
else
  log_info "Exporting full pack"
  packwiz modrinth export
fi

# Move any resulting .mrpack to project root
if ls *.mrpack &>/dev/null 2>&1; then
  mv -- *.mrpack "$PROJECT_ROOT/" 2>/dev/null || true
fi

log_info "Export complete"
printf 'File: %s\n' "$PROJECT_ROOT"/*.mrpack 2>/dev/null || printf 'Check packwiz/ for exported file\n'
