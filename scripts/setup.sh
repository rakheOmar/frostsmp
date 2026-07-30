#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

check_deps() {
  local -a missing=()
  local cmd
  for cmd in docker compose; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    exit 1
  fi
}

cd "$PROJECT_ROOT"
check_deps

if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    log_info "Created .env from .env.example — edit it before the server starts"
  else
    log_error "No .env or .env.example found"
    exit 1
  fi
fi

if [[ -x scripts/setup-mods.sh ]]; then
  scripts/setup-mods.sh
fi

log_info "Starting minecraft container"
docker compose up -d minecraft

log_info "Waiting for server health check..."
if ! docker compose exec -T minecraft bash -c '
  for i in $(seq 60); do
    mc-health 2>/dev/null && exit 0
    sleep 5
  done
  exit 1
'; then
  log_error "Server did not become healthy within 5 minutes"
  docker compose logs --tail=20 minecraft
  exit 1
fi

log_info "Starting playit tunnel"
docker compose up -d playit

log_info "Setup complete"
printf 'Attach to console:  docker attach frostsmp\n'
printf 'View logs:         docker compose logs -f minecraft\n'
