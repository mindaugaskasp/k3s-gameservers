# Palworld

Runs [`thijsvanloef/palworld-server-docker`](https://github.com/thijsvanloef/palworld-server-docker).

## Data and config

- **PVC** is mounted at `/palworld`: the steamcmd install, with the world,
  settings and logs under `Pal/Saved/` and the image's backups in `backups/`.
- **`PalWorldSettings.ini`** is rewritten from the env vars on every boot, so
  edit values and `.env`, not the file.
- **First boot** downloads the game; the server is unreachable until it
  finishes, and an update needs up to twice the game size on disk.
- **Settings** come from values, and `games/palworld/.env` overrides the common
  ones (name, slots, world rules) without editing them.

## Updates and backups

- **Updates:** steamcmd checks on every container start (`UPDATE_ON_BOOT`);
  there is no in-place update, so updating a running server is `make restart`.
  Check `make players` first: a restart disconnects everyone.
- **Backups** (`backups.cron`) tar `Pal/Saved/` into `backups/`; archives older
  than `backups.keepDays` are deleted. `make backup-now` takes one right away,
  `make restore-backup` unpacks one back into `Pal/`.

## Alerts and probes

- **Alerts:** start and stop come from Kubernetes `postStart`/`preStop` hooks,
  like every other game here; the image's own Discord posts (start, stop,
  join/leave, each backup) are switched off so nothing posts twice. Its
  update-on-boot posts stay on: the shared hooks have no update event.
- **Probes:** startup and liveness both watch the `PalServer-Linux` process.

## Ports and admin

- **One UDP port** (`server.gamePort`, default 8211) carries the game traffic.
- **RCON and the REST API stay pod-only**: the image saves the world over RCON
  on stop, and the exporter asks the REST API for status. Both grant admin
  commands, so neither is ever a NodePort.
- **Player stats:** the game answers no public query protocol; the sidecar asks
  the [REST API](https://tech.palworldgame.com/category/rest-api) with the
  admin password. It names online players, so there is no log to follow; no
  endpoint records deaths.
