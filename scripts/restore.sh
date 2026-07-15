#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
cd "$PROJECT_ROOT"

log_info()  { printf '[%s] INFO:  %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_warn()  { printf '[%s] WARN:  %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] ERROR: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

DRY_RUN="${DRY_RUN:-false}"
SERVER_STOPPED=false

cleanup() {
  if [[ "$SERVER_STOPPED" == "true" ]]; then
    log_warn "Script exiting — restarting server..."
    docker compose start minecraft 2>/dev/null || true
  fi
}

trap 'log_error "Script failed at line $LINENO"' ERR
trap 'cleanup' EXIT

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[DRY RUN] Would execute: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

BACKUP_DIR="backups"
WORLD_DIR="server/world"

if [[ ! -d "$BACKUP_DIR" ]]; then
  log_error "Backup directory $BACKUP_DIR does not exist."
  exit 1
fi

mapfile -t BACKUPS < <(ls -1t "$BACKUP_DIR"/backup-*.tar.zst 2>/dev/null || true)

if [[ ${#BACKUPS[@]} -eq 0 ]]; then
  log_error "No backup archives found in $BACKUP_DIR."
  exit 1
fi

echo "=== FrostSMP Restore ==="
echo "Available backups:"
for i in "${!BACKUPS[@]}"; do
  SIZE=$(stat -c %s "${BACKUPS[$i]}" 2>/dev/null | numfmt --to=iec 2>/dev/null || ls -lh "${BACKUPS[$i]}" | awk '{print $5}')
  printf '  %d) %s  (%s)\n' "$((i + 1))" "$(basename "${BACKUPS[$i]}")" "$SIZE"
done
echo ""

read -rp "Select backup to restore (1-${#BACKUPS[@]}): " SELECTION

if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [[ "$SELECTION" -lt 1 ]] || [[ "$SELECTION" -gt "${#BACKUPS[@]}" ]]; then
  log_error "Invalid selection."
  exit 1
fi

SELECTED="${BACKUPS[$((SELECTION - 1))]}"

log_info "Stopping server..."
run_cmd docker compose stop minecraft -t 60
SERVER_STOPPED=true

if [[ -d "$WORLD_DIR" ]] && [[ -n "$(find "$WORLD_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  TIMESTAMP=$(date +%Y-%m-%d-%H%M)
  PRE_RESTORE="${BACKUP_DIR}/pre-restore-${TIMESTAMP}.tar.zst"
  log_info "Backing up current world before restore..."
  mkdir -p "$BACKUP_DIR"
  run_cmd tar -cf - -C "$WORLD_DIR" . | run_cmd zstd -o "$PRE_RESTORE"
  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ ${PIPESTATUS[1]} -ne 0 ]]; then
    log_error "Pre-restore backup failed."
    exit 1
  fi
  log_info "Pre-restore backup saved: $PRE_RESTORE"
fi

log_info "Removing current world..."
run_cmd rm -rf "$WORLD_DIR"
run_cmd mkdir -p "$WORLD_DIR"

log_info "Extracting backup: $(basename "$SELECTED")..."
run_cmd zstd -d -c "$SELECTED" | run_cmd tar -xf - -C "$WORLD_DIR"
if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ ${PIPESTATUS[1]} -ne 0 ]]; then
  log_error "Restore extraction failed."
  exit 1
fi

log_info "Starting server..."
run_cmd docker compose start minecraft
SERVER_STOPPED=false

echo ""
echo "=== Restore complete ==="
