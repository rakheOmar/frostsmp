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

# Idempotent mod add — skips if .pw.toml already exists
pw_add() {
  local url="$1"
  local slug
  slug="$(basename "$url")"
  if [[ -f "mods/${slug}.pw.toml" ]]; then
    log_info "Skipping — already added: $slug"
    return 0
  fi
  run_cmd packwiz add "$url"
}

pw_datapack_add() {
  local url="$1"
  local slug
  slug="$(basename "$url")"
  if [[ -f "datapacks/${slug}.pw.toml" ]]; then
    log_info "Skipping — already added: $slug"
    return 0
  fi
  run_cmd packwiz datapack add "$url"
}

printf '=== FrostSMP Mod Setup ===\n'
printf 'This script adds all mods and datapacks via packwiz.\n'
printf 'Run it once on the target Linux machine.\n'
printf '\n'

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

pw_add https://modrinth.com/mod/ferrite-core
pw_add https://modrinth.com/mod/modernfix
pw_add https://modrinth.com/mod/memoryleakfix
pw_add https://modrinth.com/mod/fastload
pw_add https://modrinth.com/mod/embeddium
pw_add https://modrinth.com/mod/immediatelyfast
pw_add https://modrinth.com/mod/entityculling

pw_add https://modrinth.com/mod/better-combat
pw_add https://modrinth.com/mod/combat-roll

pw_add https://modrinth.com/mod/farmers-delight
pw_add https://modrinth.com/mod/supplementaries
pw_add https://modrinth.com/mod/waystones
pw_add https://modrinth.com/mod/corpse
pw_add https://modrinth.com/mod/jade
pw_add https://modrinth.com/mod/emi
pw_add https://modrinth.com/mod/appleskin
pw_add https://modrinth.com/mod/natures-compass
pw_add https://modrinth.com/mod/explorers-compass
pw_add https://modrinth.com/mod/mouse-tweaks

pw_add https://www.curseforge.com/minecraft/mc-mods/when-dungeons-arise
# Unofficial 1.21.1 port — original Alex's Mobs stopped at 1.20.1
pw_add https://www.curseforge.com/minecraft/mc-mods/alexs-mobs-1-21-1-port
pw_add https://modrinth.com/mod/friends-and-foes-forge
pw_add https://www.curseforge.com/minecraft/mc-mods/born-in-chaos
pw_add https://www.curseforge.com/minecraft/mc-mods/l-ender-s-cataclysm
pw_add https://www.curseforge.com/minecraft/mc-mods/mowzies-mobs
pw_add https://www.curseforge.com/minecraft/mc-mods/artifacts
pw_add https://www.curseforge.com/minecraft/mc-mods/relics-mod

# --- Library dependencies ---
pw_add https://modrinth.com/mod/moonlight        # required by Supplementaries
pw_add https://modrinth.com/mod/curios           # required by Relics
pw_add https://www.curseforge.com/minecraft/mc-mods/octo-lib  # required by Relics (1.19.2+)

printf '\n--- Adding datapacks ---\n\n'

pw_datapack_add https://modrinth.com/datapack/terralith
pw_datapack_add https://modrinth.com/datapack/incendium
pw_datapack_add https://modrinth.com/datapack/nullscape
pw_datapack_add https://modrinth.com/datapack/dungeons-and-taverns
pw_datapack_add https://modrinth.com/datapack/ct-overhaul-village

printf '\n--- Refreshing index ---\n'
run_cmd packwiz refresh

printf '\n--- Installing mods ---\n'
run_cmd packwiz install

printf '\n--- Installing datapacks ---\n'
run_cmd packwiz datapack install --directory ../server/world

printf '\n=== Mod setup complete ===\n'
printf '\nThe following files are now generated and should be committed:\n'
printf '  - packwiz/mods/*.pw.toml\n'
printf '  - packwiz/index.toml\n'
printf '  - packwiz/datapacks/*.pw.toml\n'
printf '\nRestart the server:\n'
printf '  docker compose restart minecraft\n'
