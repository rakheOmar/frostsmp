# Setup Guide

## Prerequisites

- Docker + Compose V2 on the host
- `packwiz` CLI — [download](https://packwiz.infra.link/installation/) and put it in `$PATH`

## First-time setup

```bash
# 1. Clone and enter
git clone <repo-url> frostsmp
cd frostsmp

# 2. Configure environment
cp .env.example .env
vim .env   # set SEED, RCON_PASSWORD, PLAYIT_SECRET_KEY, etc.

# 3. Install mods (skip if packwiz/mods/*.pw.toml already exist)
#    Edit scripts/mods.txt with Modrinth slugs, or drop .pw.toml files into packwiz/mods/
./scripts/setup-mods.sh

# 4. Start the server
./scripts/setup.sh
```

## Adding mods

```bash
cd packwiz
packwiz mr install <mod-slug>     # from Modrinth
packwiz cf install <mod-slug>     # from CurseForge
packwiz refresh
cd ..
docker compose restart minecraft
```

## Updating mods

```bash
./scripts/update.sh
```

## Backup and restore

```bash
./scripts/backup.sh                        # creates backups/frostsmp-<date>.tar.gz
./scripts/restore.sh backups/frostsmp-<date>.tar.gz
```

## World management

```bash
./scripts/pregen.sh 5000                   # pre-generate 5000x5000 area
./scripts/reset-world.sh --confirm          # wipe world and restart
```
