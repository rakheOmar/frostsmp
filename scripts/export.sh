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

: "${MC_VERSION:?MC_VERSION is not set in .env}"
: "${NEOFORGE_VERSION:=<not set>}"

DIST="dist"
STAGING="${DIST}/FrostSMP-${MC_VERSION}"

printf '=== FrostSMP Client Export ===\n'

if [[ -d "$STAGING" ]]; then
  run_cmd rm -rf -- "$STAGING"
fi

run_cmd mkdir -p "$STAGING/mods" "$STAGING/config" "$STAGING/resourcepacks"

log_info "Copying mods..."
shopt -s nullglob
mods=(server/mods/*.jar)
shopt -u nullglob
if [[ ${#mods[@]} -gt 0 ]]; then
  run_cmd cp "${mods[@]}" "$STAGING/mods/"
  log_info "Copied ${#mods[@]} mod(s)"
else
  log_warn "No mod jars found in server/mods/"
fi

log_info "Copying config..."
if [[ -d server/config ]] && [[ -n "$(find server/config -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  run_cmd cp -r server/config/* "$STAGING/config/"
  log_info "Config copied"
else
  log_warn "No config files found in server/config/"
fi

log_info "Copying resource packs..."
if [[ -d server/resourcepacks ]] && [[ -n "$(find server/resourcepacks -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  run_cmd cp -r server/resourcepacks/* "$STAGING/resourcepacks/"
  log_info "Resource packs copied"
else
  log_warn "No resource packs found in server/resourcepacks/"
fi

cat > "$STAGING/README.txt" << EOF
FrostSMP - Client Package
Minecraft: $MC_VERSION
Mod Loader: NeoForge $NEOFORGE_VERSION

Installation:
1. Install Minecraft $MC_VERSION
2. Install NeoForge $NEOFORGE_VERSION for $MC_VERSION
3. Copy the mods/ folder into your Minecraft instance directory
4. Copy the config/ folder into your Minecraft instance directory (optional)
5. Copy the resourcepacks/ folder into your resourcepacks directory (optional)
6. Launch NeoForge and connect to the server

Server address: <your-server-ip>:25565
EOF

# --------------------------------------------------
# Output 1: plain ZIP (drag-and-drop into instance)
# --------------------------------------------------
ARCHIVE="${DIST}/FrostSMP-${MC_VERSION}.zip"
log_info "Creating ZIP package..."
run_cmd mkdir -p "$DIST"
run_cmd rm -f "$ARCHIVE"
cd "$DIST"
run_cmd zip -qr "$(basename "$ARCHIVE")" "$(basename "$STAGING")"
cd "$PROJECT_ROOT"
log_info "ZIP created: $ARCHIVE"

# --------------------------------------------------
# Output 2: Modrinth .mrpack (one-click in Prism)
# --------------------------------------------------
MRPACK="${DIST}/FrostSMP-${MC_VERSION}.mrpack"
MRPACK_STAGING="${DIST}/.mrpack-staging"
log_info "Creating Modrinth pack for Prism Launcher..."

run_cmd rm -rf "$MRPACK_STAGING"
run_cmd mkdir -p "$MRPACK_STAGING/overrides"

# Move the mods/config/resourcepacks into overrides/
run_cmd cp -r "$STAGING/mods" "$MRPACK_STAGING/overrides/"
run_cmd cp -r "$STAGING/config" "$MRPACK_STAGING/overrides/"
run_cmd cp -r "$STAGING/resourcepacks" "$MRPACK_STAGING/overrides/"

cat > "$MRPACK_STAGING/modrinth.index.json" << EOF
{
  "formatVersion": 1,
  "game": "minecraft",
  "versionId": "${MC_VERSION}",
  "name": "FrostSMP",
  "summary": "FrostSMP server modpack",
  "files": [],
  "dependencies": {
    "minecraft": "${MC_VERSION}",
    "neoforge": ">=${NEOFORGE_VERSION}"
  }
}
EOF

run_cmd rm -f "$MRPACK"
cd "$MRPACK_STAGING"
run_cmd zip -qr "../$(basename "$MRPACK")" .
cd "$PROJECT_ROOT"
run_cmd rm -rf "$MRPACK_STAGING"

# --------------------------------------------------
# Cleanup
# --------------------------------------------------
run_cmd rm -rf -- "$STAGING"

log_info "Package created: $ARCHIVE"
log_info "Prism pack created: $MRPACK"
ls -lh "$ARCHIVE" "$MRPACK"
