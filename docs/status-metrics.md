# Status metrics sidecar

`game-status-metrics/` queries the game server next to it with
[gamedig](https://github.com/gamedig/node-gamedig) and serves the result as
Prometheus text on `:9101/metrics` (`/healthz` for probes).

Most numbers no query protocol reports -- uptime, mods, backups -- come from
files the chart's lifecycle hooks write, so each reader below is one file format.

## Wiring

- `index.js`: HTTP server, the 15s query loop, and the env-var check.
- `config.js`: every env var and the paths derived from it.
- `game-server-query.js`: runs the gamedig query, keeps the last answer for
  the next scrape.
- `metrics-text.js`: joins the metric lines into the text served on `/metrics`.

## Readers

- `status-files.js`: `STATUS_DIR` files -- start/update timestamps, build id,
  mod state, last player activity.
- `online-players.js`: who is online now, one `STATUS_DIR` file per player from
  the game's log (Valheim's hooks, Enshrouded's reader); mtime is when they joined.
- `log-follower.js`: the lines a log file gained since the last read. Offsets are
  kept in `STATUS_DIR`, so an exporter restart neither replays nor skips a line; a
  new inode at the same path, a log the game moved away, starts over.
- `death-log-reader.js`: deaths the log hooks appended to the shared death log.
- `zomboid-log-reader.js`: deaths from Zomboid's `user` and `pvp` logs.
- `enshrouded-log-reader.js`: players joining and leaving, and the world's base count.
- `player-database.js`: `<DATABASE_DIR>/<game>-players.db` on the PVC, one per
  game -- time online, deaths, zombie kills, last seen. This process is its only writer: one
  running as another user would leave [WAL](https://sqlite.org/wal.html) files
  this one cannot write, and every query would fail as "readonly database".
- `database-migrations.js` + `migrations/`: one file per schema version, applied
  in filename order on connect and recorded in the `migration` table. Add a file,
  never edit one that has shipped.
- `reset-player-stats.js`: run by `make reset-player-stats`; saves a copy of the
  database first. `make read-player-db` opens a read-only `sqlite3` shell on it.
- `world-modifiers.js`: world rules parsed out of the server's command line.
- `backup-files.js`: backup archives on disk, oldest first.
- `backup-archive.js`: the `.play-clock` index and play-time retention
  windows, mirroring `backup-prune.sh`.

## Metric lines

`metric-lines.js` escapes label values and builds one gauge's `# HELP`, `# TYPE`
and sample lines; a gauge with no samples prints nothing. Gauge is the metric
type named on every `# TYPE` line of the
[exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/).

- `metrics/game-server-metrics.js`: `game_server_*`, what every game answers.
- `metrics/backup-metrics.js`: `game_server_backup_*`.
- `metrics/valheim-metrics.js`: `valheim_*` mods and world modifiers.
- `metrics/zomboid-metrics.js`: `zomboid_*` zombie kills per player.
- `metrics/enshrouded-metrics.js`: `enshrouded_*` player-built bases in the world.
- `metrics/backup-archive-metrics.js`: `valheim_backup_*` archive windows.

Metric naming rules live in [CLAUDE.md](../CLAUDE.md); a published name is an
interface, so grep `grafana/` before renaming one.
