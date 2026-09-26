# Minecraft

Runs [`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server) with
[Paper](https://papermc.io/), for Java Edition clients. Setup: [setup.md](setup.md).

## Image and data

- **Settings** come from env vars the image writes into `server.properties` on every start;
  a setting changed by hand in that file is overwritten unless it has no env var.
- **Volume:** `minecraft/` holds the server (`/data`), `backups/` the backups, and
  `database/sqlite/` the exporter's player history.
- **Stop:** the image stops the server over RCON and waits up to 60s for it to save.

## Backups

The [`mc-backup`](https://github.com/itzg/docker-mc-backup) sidecar tars the world every
`backups.interval`, pausing saves over RCON while it does, and skips a run while nobody is on.
Tars older than `backups.pruneDays` are deleted.

- `make sync` copies the server and the tars to `data/` and `data-backups/`.
- `make restore-backup` swaps `world`, `world_nether` and `world_the_end` for a tar's copies,
  keeping the old ones in `.replaced-<time>/`; config and plugins stay.

## Monitoring

The status-metrics sidecar queries the server list ping, which names online players.
Operators in `ops.json` show as admins; difficulty, game mode, hardcore and PvP from
`server.properties` are `minecraft_world_setting`. Deaths aren't recorded yet.
