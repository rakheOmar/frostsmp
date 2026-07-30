#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_warn() { printf '[%s] WARN: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

PACKWIZ_DIR="$PROJECT_ROOT/packwiz"
MODLIST="${MODLIST:-$PACKWIZ_DIR/mods.txt}"

check_deps() {
  local -a missing=()
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    return 1
  fi
}

check_deps packwiz || {
  log_error "packwiz not found in PATH"
  log_error "Download from: https://packwiz.infra.link/installation/"
  exit 1
}

cd "$PACKWIZ_DIR"

if [[ -d mods ]] && ls mods/*.pw.toml &>/dev/null 2>&1; then
  log_info "Found existing .pw.toml files — refreshing index and updating mods"
  packwiz refresh
  packwiz update --all
elif [[ -f "$MODLIST" ]]; then
  log_info "Reading mod list from $MODLIST"
  while IFS= read -r mod; do
    [[ -z "$mod" || "$mod" == \#* ]] && continue
    log_info "Installing $mod"
    packwiz mr install "$mod"
  done < "$MODLIST"
  packwiz refresh
else
  log_warn "No .pw.toml files in packwiz/mods/ and no mods.txt found"
  log_warn "Place .pw.toml files in packwiz/mods/ or create packwiz/mods.txt with one slug per line"
  exit 0
fi

log_info "Mod setup complete"
