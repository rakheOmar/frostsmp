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

pw_install() {
  local url="$1"
  local slug
  slug="$(basename "$url")"

  # Remove trailing slash from slug if present
  slug="${slug%/}"
  # For CurseForge URLs, the slug is the last path component
  # For Modrinth URLs, also the last path component

  if [[ -f "mods/${slug}.pw.toml" ]] || [[ -f "datapacks/${slug}.pw.toml" ]]; then
    log_info "Skipping — already added: $slug"
    return 0
  fi

  if [[ "$url" == *"curseforge.com"* ]]; then
    run_cmd packwiz cf install "$url" -y
  else
    run_cmd packwiz mr install "$url" -y
  fi
}

printf '=== FrostSMP Mod Setup ===\n'
printf 'This script adds all mods and datapacks via packwiz.\n'
printf 'Run it once on the target Linux machine.\n\n'

if [[ ! -f packwiz/pack.toml ]]; then
  log_error "packwiz/pack.toml not found. Run from the project root."
  exit 1
fi

if ! command -v packwiz &>/dev/null; then
  log_info "packwiz not found. Installing via Go..."
  if ! command -v go &>/dev/null; then
    log_error "Go is required to install packwiz."
    log_error "Install Go first: https://go.dev/dl/"
    log_error "Or install packwiz manually: https://packwiz.infra.link/installation/"
    exit 1
  fi
  go install github.com/packwiz/packwiz@latest
  export PATH="$HOME/go/bin:$PATH"
  if ! command -v packwiz &>/dev/null; then
    log_error "packwiz installation failed."
    exit 1
  fi
  log_info "packwiz installed"
fi

cd packwiz

printf '\n--- Adding mods ---\n\n'

pw_install https://modrinth.com/mod/ferrite-core
pw_install https://modrinth.com/mod/modernfix
# memoryleakfix removed — Fabric-only, no NeoForge version (ModernFix covers this)
# fastload removed — only up to 1.20.1, and it's client-side only
pw_install https://modrinth.com/mod/embeddium
pw_install https://modrinth.com/mod/immediatelyfast
pw_install https://modrinth.com/mod/entityculling

pw_install https://modrinth.com/mod/better-combat
pw_install https://modrinth.com/mod/combat-roll

pw_install https://modrinth.com/mod/farmers-delight
pw_install https://modrinth.com/mod/supplementaries
pw_install https://modrinth.com/mod/waystones
pw_install https://modrinth.com/mod/corpse
pw_install https://modrinth.com/mod/jade
pw_install https://modrinth.com/mod/emi
pw_install https://modrinth.com/mod/appleskin
pw_install https://modrinth.com/mod/natures-compass
pw_install https://modrinth.com/mod/explorers-compass
pw_install https://modrinth.com/mod/mouse-tweaks

# --- Library deps (needed before the mods that require them) ---
pw_install https://modrinth.com/mod/moonlight          # Supplementaries
pw_install https://modrinth.com/mod/curios             # Relics
pw_install https://modrinth.com/mod/shatterbyte-lib  # OctoLib (required by Relics)

pw_install https://www.curseforge.com/minecraft/mc-mods/when-dungeons-arise
# Unofficial 1.21.1 port — original Alex's Mobs stopped at 1.20.1
pw_install https://www.curseforge.com/minecraft/mc-mods/alexs-mobs-1-21-1-port
pw_install https://modrinth.com/mod/friends-and-foes-forge
pw_install https://www.curseforge.com/minecraft/mc-mods/born-in-chaos
pw_install https://modrinth.com/mod/l_enders-cataclysm
pw_install https://www.curseforge.com/minecraft/mc-mods/mowzies-mobs
pw_install https://www.curseforge.com/minecraft/mc-mods/artifacts
pw_install https://www.curseforge.com/minecraft/mc-mods/relics-mod

pw_install https://modrinth.com/mod/chunky           # World pre-generation

printf '\n--- Adding datapacks ---\n\n'

# Modrinth datapacks are added the same way — packwiz detects the project type
pw_install https://modrinth.com/datapack/terralith
pw_install https://modrinth.com/datapack/incendium
pw_install https://modrinth.com/datapack/nullscape
pw_install https://modrinth.com/datapack/dungeons-and-taverns
pw_install https://modrinth.com/datapack/ct-overhaul-village

printf '\n--- Refreshing index ---\n'
run_cmd packwiz refresh

printf '\n--- Copying mod jars to server/mods/ ---\n'
# packwiz stores downloaded JARs alongside their .pw.toml metadata
run_cmd mkdir -p server/mods
# Remove stale JARs before copying to avoid orphaned mods
shopt -s nullglob
stale_jars=(server/mods/*.jar)
if [[ ${#stale_jars[@]} -gt 0 ]]; then
  run_cmd rm -f "${stale_jars[@]}"
fi
shopt -u nullglob
if ls packwiz/mods/*.jar &>/dev/null; then
  run_cmd cp packwiz/mods/*.jar server/mods/
  log_info "Mod jars copied from packwiz/mods/ to server/mods/"
else
  log_warn "No mod jars found in packwiz/mods/ — trying alternate copy from packwiz cache"
  # fallback: try to copy from the system packwiz cache
  PACKWIZ_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/packwiz/cache"
  if [[ -d "$PACKWIZ_CACHE" ]] && ls "$PACKWIZ_CACHE"/*.jar &>/dev/null; then
    run_cmd cp "$PACKWIZ_CACHE"/*.jar server/mods/
    log_info "Mod jars copied from packwiz cache to server/mods/"
  else
    log_warn "No mod jars found in packwiz cache either — mods may need to be re-added"
  fi
fi

printf '\n--- Copying datapacks ---\n'
run_cmd mkdir -p server/world/datapacks
if ls packwiz/datapacks/*.zip &>/dev/null; then
  run_cmd cp packwiz/datapacks/*.zip server/world/datapacks/
  log_info "Datapacks copied from packwiz/datapacks/ to server/world/datapacks/"
fi

printf '\n=== Mod setup complete ===\n'
printf '\nRestart the server:\n'
printf '  docker compose restart minecraft\n'
