# Status metrics sidecar

Each game's pod runs its own status-metrics sidecar, which queries the game server next to it
with [gamedig](https://github.com/gamedig/node-gamedig) and serves Prometheus text on
`:9101/metrics` (`/healthz` for probes).

- `game-server/status-metrics/`: what every game shares. It names no game.
- `games/<game>/status-metrics/`: what only that game records and reports, its
  `config.js` and its migrations, listed in its `status-metrics/README.md`.

How Valheim's stats reach Grafana and the website: [metrics-flow.md](metrics-flow.md).

## Image

One per game, `<game>-status-metrics`, built from `game-server/status-metrics/Dockerfile` with
the game's folder as the `game` [build context](https://docs.podman.io/en/latest/markdown/podman-build.1.html#build-context-name-value).
The image keeps the repo layout, so a game's relative `require`s of the core resolve as they do here.
`game-server/make/metrics-image.mk` tags it with the last commit touching either folder.

## Game plugin

`games/<game>/status-metrics/game-plugin.js` is the only file the core calls into.
`load-game-plugin.js` loads it from `GAME_DIR` and lists every member it must have.
Only the entry points (`index.js`, `reset-player-stats.js`) load it.

## Shared modules

- `index.js`: HTTP server, the 15s query loop, and the env-var check.
- `config.js`: the env vars every game has and the paths derived from them.
- `query-game-server.js`: runs the gamedig query, keeps the last answer for the next scrape.
- `build-metrics-text.js`: joins the metric lines into the text served on `/metrics`.
- `read-status-files.js`: hook-written `STATUS_DIR` timestamps, build ID and past uptime.
- `track-online-players.js`: who is online, one `STATUS_DIR` file per player from the log; mtime = joined.
- `read-new-log-lines.js`: the lines a log file gained since the last read. Offsets are
  kept in `STATUS_DIR`, so an exporter restart neither replays nor skips a line; a
  new inode at the same path, a log the game moved away, starts over.
- `read-backups.js`: backup archives on disk, oldest first.
- The player database and its modules: [player-database.md](player-database.md).

## Metric lines

`format-metric-lines.js` builds one gauge's [exposition](https://prometheus.io/docs/instrumenting/exposition_formats/)
lines; a gauge with no samples prints nothing.

- `metrics/build-game-server-metrics.js`: `game_server_*`, what every game answers.
- `metrics/build-backup-metrics.js`: `game_server_backup_*`.
- The game's own metrics come from its plugin's `buildMetricLines`.

Metric naming rules live in [CLAUDE.md](../CLAUDE.md); a published name is an
interface, so grep `grafana/` before renaming one.
