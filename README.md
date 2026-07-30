# FrostSMP

NeoForge Minecraft server running in Docker with packwiz mod management.

## Quick start

```bash
cp .env.example .env    # configure
./scripts/setup.sh      # install mods + start server
```

## Structure

| Path | Contents |
|------|----------|
| `packwiz/` | Mod metadata (`.pw.toml` files), tracked |
| `server/config/` | Mod configs, tracked |
| `server/world/` | World data, gitignored |
| `server/mods/` | Downloaded JARs, gitignored |
| `scripts/` | Management scripts |
| `guides/` | Detailed documentation |

See `guides/setup-guide.md` for detailed walkthrough.
