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

printf '=== FrostSMP Setup ===\n'

if ! command -v docker &>/dev/null; then
  log_error "Docker is not installed. Install it first: https://docs.docker.com/engine/install/"
  exit 1
fi
log_info "Docker found"

if ! docker compose version &>/dev/null; then
  log_error "Docker Compose is not available."
  exit 1
fi
log_info "Docker Compose found"

mkdir -p server/config server/world server/logs server/mods server/resourcepacks server/datapacks backups dist

if [[ ! -f .env ]]; then
  if [[ ! -f .env.example ]]; then
    log_error ".env.example is missing — cannot create .env"
    exit 1
  fi
  cp .env.example .env
  log_info "Created .env from .env.example — edit it before starting the server."
else
  log_info ".env already exists"
fi

if [[ ! -f packwiz/pack.toml ]]; then
  log_error "packwiz/pack.toml is missing."
  exit 1
fi

if ! command -v packwiz &>/dev/null; then
  log_info "packwiz not found locally — will run inside container or use go install."
  log_info "Install with: go install github.com/packwiz/packwiz@latest"
else
  log_info "packwiz found"
fi

if [[ -d server/world ]] && [[ -n "$(find server/world -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  printf '\nWorld already exists at server/world/\n'
  printf 'Current world will NOT be regenerated.\n'
  printf '\nDelete server/world or run:\n'
  printf '  ./scripts/reset-world.sh\n'
  printf 'to generate a new world using the configured seed.\n'
else
  log_info "server/world is empty — a new world will be created on first start."
fi

printf '\n=== Setup complete ===\n'
printf '\nNext steps:\n'
printf '  1. Edit .env with your settings\n'
printf '  2. Add mods with: packwiz add <mod-url>\n'
printf '  3. Run: docker compose up -d\n'
