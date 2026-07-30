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

log_info "Setting acceptable Minecraft versions"
packwiz settings acceptable-versions --add 1.21.1 || true

MOD_COUNT=$(jq length "$MODS_JSON")
log_info "Processing $MOD_COUNT mods from $MODS_JSON"

INSTALLED=0
SKIPPED=0
FAILED=0

for i in $(seq 0 $((MOD_COUNT - 1))); do
  SOURCE=$(jq -r ".[$i].source" "$MODS_JSON")
  SLUG=$(jq -r ".[$i].slug" "$MODS_JSON")
  OPTIONAL=$(jq -r ".[$i].optional // false" "$MODS_JSON")
  NAME=$(jq -r ".[$i].name" "$MODS_JSON")

  if [[ -f "mods/${SLUG}.pw.toml" ]]; then
    log_info "[$((i + 1))/$MOD_COUNT] Skipping $NAME — already installed"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [[ "$OPTIONAL" == "true" ]]; then
    log_warn "OPTIONAL: $NAME ($SLUG) — installing may fail if unavailable"
  fi

  case "$SOURCE" in
    modrinth)
      log_info "[$((i + 1))/$MOD_COUNT] Installing $NAME (modrinth: $SLUG)"
      if packwiz mr install -y "$SLUG" 2>&1 | while IFS= read -r line; do log_info "$line"; done; then
        INSTALLED=$((INSTALLED + 1))
      else
        log_warn "Failed to install $NAME — continuing"
        FAILED=$((FAILED + 1))
      fi
      ;;
    curseforge)
      log_info "[$((i + 1))/$MOD_COUNT] Installing $NAME (curseforge: $SLUG)"
      if packwiz cf install -y "$SLUG" 2>&1 | while IFS= read -r line; do log_info "$line"; done; then
        INSTALLED=$((INSTALLED + 1))
      else
        log_warn "Failed to install $NAME — continuing"
        FAILED=$((FAILED + 1))
      fi
      ;;
    *)
      log_warn "Unknown source '$SOURCE' for $SLUG — skipping"
      FAILED=$((FAILED + 1))
      ;;
  esac
done

log_info "Regenerating packwiz index"
packwiz refresh

log_info "Done: $INSTALLED installed, $SKIPPED already present, $FAILED failed"
