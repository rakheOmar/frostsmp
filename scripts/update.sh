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

printf '=== FrostSMP Update ===\n'

if ! command -v packwiz &>/dev/null; then
  log_error "packwiz is not installed."
  log_error "Install: go install github.com/packwiz/packwiz@latest"
  exit 1
fi

log_info "Refreshing packwiz index..."
cd packwiz
run_cmd packwiz refresh
cd "$PROJECT_ROOT"

log_info "Exporting mods to server/mods/..."
export_ok=0
run_cmd packwiz curseforge export --output server/mods/ 2>/dev/null && export_ok=1
if [[ $export_ok -eq 0 ]]; then
  run_cmd packwiz modrinth export --output server/mods/ 2>/dev/null && export_ok=1
fi
if [[ $export_ok -eq 0 ]]; then
  if [[ -d server/mods ]] && ls server/mods/*.jar &>/dev/null; then
    log_warn "packwiz export failed, but mod jars already exist — continuing"
  else
    log_warn "packwiz export failed and no mod jars found — update may be incomplete"
  fi
fi

log_info "Restarting server container..."
run_cmd docker compose restart minecraft

log_info "Waiting for health check..."
sleep 10
docker compose ps minecraft

printf '\n=== Update complete ===\n'
