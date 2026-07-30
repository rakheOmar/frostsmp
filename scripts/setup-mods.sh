#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

log_info() { printf '[%s] INFO: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_warn() { printf '[%s] WARN: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

PACKWIZ_DIR="$PROJECT_ROOT/packwiz"
MODS_JSON="${MODS_JSON:-$PACKWIZ_DIR/mods.json}"

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

check_deps jq packwiz

if [[ ! -f "$MODS_JSON" ]]; then
  log_error "Mod list not found at $MODS_JSON"
  exit 1
fi

cd "$PACKWIZ_DIR"

if [[ -d mods ]] && ls mods/*.pw.toml &>/dev/null 2>&1; then
  log_info "Existing .pw.toml files found — refreshing and updating"
  packwiz refresh
  packwiz update --all
  log_info "Mod update complete"
  exit 0
fi

MOD_COUNT=$(jq length "$MODS_JSON")
log_info "Installing $MOD_COUNT mods from $MODS_JSON"

for i in $(seq 0 $((MOD_COUNT - 1))); do
  SOURCE=$(jq -r ".[$i].source" "$MODS_JSON")
  SLUG=$(jq -r ".[$i].slug" "$MODS_JSON")
  OPTIONAL=$(jq -r ".[$i].optional // false" "$MODS_JSON")
  NAME=$(jq -r ".[$i].name" "$MODS_JSON")

  if [[ "$OPTIONAL" == "true" ]]; then
    log_warn "OPTIONAL: $NAME ($SLUG) — installing may fail if unavailable"
  fi

  case "$SOURCE" in
    modrinth)
      log_info "[$((i + 1))/$MOD_COUNT] Installing $NAME (modrinth: $SLUG)"
      packwiz mr install "$SLUG" 2>&1 | while IFS= read -r line; do log_info "$line"; done
      ;;
    curseforge)
      log_info "[$((i + 1))/$MOD_COUNT] Installing $NAME (curseforge: $SLUG)"
      packwiz cf install "$SLUG" 2>&1 | while IFS= read -r line; do log_info "$line"; done
      ;;
    *)
      log_warn "Unknown source '$SOURCE' for $SLUG — skipping"
      ;;
  esac
done

log_info "Regenerating packwiz index"
packwiz refresh

log_info "Mod setup complete"
