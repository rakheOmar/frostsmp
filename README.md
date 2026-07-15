# FrostSMP

A Docker-based NeoForge Minecraft server with ~30 mods and datapack-driven worldgen.

## Requirements

- Docker Engine + Compose plugin
- Go 1.21+ (optional — only if using packwiz for mod management)

## Quick start

```bash
cp .env.example .env
# edit .env with your settings

# Install mods — either:
./scripts/setup-mods.sh          # automatic (requires Go)
# or drop .jars into server/mods/ manually

docker compose up -d
```

## Scripts

| Script | Description |
|---|---|
| `setup.sh` | Verify dependencies, create directories |
| `setup-mods.sh` | Download all mods/datapacks via packwiz |
| `update.sh` | Refresh mods and restart server |
| `backup.sh` | Create zstd-compressed world backup |
| `restore.sh` | Restore world from a backup |
| `export.sh` | Build client ZIP for players |
| `pregen.sh` | Pre-generate world chunks (Chunky) |
| `reset-world.sh` | Delete world and start fresh |

## Mods

| Category | Mods |
|---|---|
| **Performance** | ModernFix, FerriteCore, MemoryLeakFix, Fastload, Embeddium, ImmediatelyFast, EntityCulling |
| **World** | Terralith, Incendium, Nullscape (datapacks) |
| **Structures** | When Dungeons Arise, Dungeons & Taverns (datapack), ChoiceTheorem's Overhauled Village (datapack) |
| **Mobs** | Alex's Mobs, Born in Chaos, Friends & Foes |
| **Bosses** | L_Ender's Cataclysm, Mowzie's Mobs |
| **Combat** | Better Combat, Combat Roll |
| **Progression** | Artifacts, Relics |
| **Survival/QoL** | Farmer's Delight, Supplementaries, Waystones, Corpse, Jade, EMI, AppleSkin, Nature's Compass, Explorer's Compass, Mouse Tweaks |

## Project structure

```
minecraft-folder/
├── docker-compose.yml
├── .env.example
├── packwiz/              # Mod pack definitions
├── server/               # Runtime data (world, config, mods, logs)
├── guides/               # Setup guides
├── backups/              # World archives
├── dist/                 # Client exports
└── scripts/              # Management scripts
```
