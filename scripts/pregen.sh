#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
cd "$PROJECT_ROOT"

log_info()  { printf '[%s] INFO:  %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_warn()  { printf '[%s] WARN:  %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

DRY_RUN="${DRY_RUN:-false}"

trap 'log_error "Script failed at line $LINENO"' ERR

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

printf '=== FrostSMP World Pre-generation ===\n\n'
printf 'This script uses Chunky to pre-generate the world.\n\n'
printf 'Prerequisites:\n'
printf '  - Chunky mod must be installed via packwiz\n'
printf '  - Server must be running\n\n'

if ! docker compose ps minecraft --format '{{.Status}}' 2>/dev/null | grep -q "^Up"; then
  log_error "Minecraft container is not running. Start it first with: docker compose up -d"
  exit 1
fi

read -rp "Radius in chunks to pre-generate (default 500): " RADIUS
RADIUS="${RADIUS:-500}"
if [[ ! "$RADIUS" =~ ^[0-9]+$ ]] || [[ "$RADIUS" -eq 0 ]]; then
  log_error "Radius must be a positive integer."
  exit 1
fi

read -rp "Dimension (overworld/nether/end, default overworld): " DIMENSION
DIMENSION="${DIMENSION:-overworld}"
case "$DIMENSION" in
  overworld|nether|end) ;;
  *)
    log_error "Dimension must be one of: overworld, nether, end."
    exit 1
    ;;
esac

printf '\nPre-generating %s with radius %s chunks...\n\n' "$DIMENSION" "$RADIUS"

run_cmd docker compose exec minecraft rcon-cli chunky radius "$RADIUS"
run_cmd docker compose exec minecraft rcon-cli chunky dimension "$DIMENSION"
run_cmd docker compose exec minecraft rcon-cli chunky start

printf '\nChunky pre-generation started.\n'
printf 'Monitor progress with:\n'
printf '  docker compose exec minecraft rcon-cli chunky progress\n\n'
printf 'To pause:  docker compose exec minecraft rcon-cli chunky pause\n'
printf 'To resume: docker compose exec minecraft rcon-cli chunky continue\n'
