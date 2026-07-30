# Operations Reference

## Container management

```bash
docker compose up -d              # start everything
docker compose down               # stop everything
docker compose restart minecraft  # restart server only
docker compose logs -f minecraft  # tail server logs
docker attach frostsmp            # interactive console (Ctrl+P Ctrl+Q to detach)
```

## RCON commands

```bash
docker compose exec -T minecraft rcon <command>
```

## File layout

```
packwiz/          # packwiz mod metadata — tracked
server/config/    # mod config files — tracked
server/world/     # world data — gitignored
server/logs/      # server logs — gitignored
server/mods/      # downloaded JARs — gitignored
scripts/          # management scripts
```

## mods.txt format

When using `setup-mods.sh` without existing `.pw.toml` files, create `packwiz/mods.txt`:

```
# Comments start with #
sodium
lithium
ferrite-core
```

## Exporting for clients

```bash
./scripts/export.sh
```

This produces a `.mrpack` file that players import via Modrinth or Prism launcher.
