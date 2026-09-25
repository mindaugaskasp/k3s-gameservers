# Status metrics sidecar

`game-status-metrics/` queries the game server next to it with [gamedig](https://github.com/gamedig/node-gamedig)
and serves Prometheus text on `:9101/metrics` (`/healthz` for probes).

Most numbers no query protocol reports -- uptime, mods, backups -- come from
files the chart's lifecycle hooks write, so each reader below is one file format.

## Wiring

- `index.js`: HTTP server, the 15s query loop, and the env-var check.
- `config.js`: every env var and the paths derived from it.
- `game-server-query.js`: runs the gamedig query, keeps the last answer for
  the next scrape.
- `metrics-text.js`: joins the metric lines into the text served on `/metrics`.

## Readers

- `status-files.js`: `STATUS_DIR` files -- start/update timestamps, build id, mod state, last activity.
- `online-players.js`: who is online, one `STATUS_DIR` file per player from the log; mtime = joined.
- `admin-players.js`: online game masters, per game: `valheim-admins.js` (Steam ID on `ADMIN_LIST_FILE`),
  `zomboid-admins.js` (admin/moderator/gm account role), `enshrouded-admins.js` (`CanKickBan` at login).
- `log-follower.js`: the lines a log file gained since the last read. Offsets are
  kept in `STATUS_DIR`, so an exporter restart neither replays nor skips a line; a
  new inode at the same path, a log the game moved away, starts over.
- `death-log-reader.js`: deaths the log hooks appended to the shared death log.
- `raid-log-reader.js`: Valheim raid starts the log hooks appended to the raid log.
- `zomboid-log-reader.js`: deaths from Zomboid's `user` and `pvp` logs.
- `enshrouded-log-reader.js`: players joining and leaving, their login permissions, the base count.
- `sqlite-database.js`: opens `<DATABASE_DIR>/<game>-players.db` on the PVC, one per game. This
  process is its only writer: another user's [WAL](https://sqlite.org/wal.html) files would make it "readonly".
- `player-database.js`: time online, deaths and the last one, zombie kills, last seen per player.
- `raid-database.js`: every Valheim raid and when it started.
- `zomboid-characters.js`: a Zomboid account's current character, stored with each of its deaths.
- `database-migrations.js` + `migrations/`: one file per schema version, applied
  in filename order on connect and recorded in the `migration` table. Add a file,
  never edit one that has shipped.
- `reset-player-stats.js`: run by `make reset-player-stats`; saves a copy of the
  database first. `make read-player-db` opens a read-only `sqlite3` shell on it.
- World settings: `world-modifiers.js` (Valheim's command line), `zomboid-sandbox.js` (SandboxVars changed
  from their commented defaults), `enshrouded-settings.js` (preset; Custom settings changed from Default).
- `world-save.js`: the `defeated_*` global keys (bosses, and a few creatures) in Valheim's newest `_main.<n>.db2`.
- `backup-files.js`: backup archives on disk, oldest first.
- `backup-archive.js`: the `.play-clock` index and play-time retention
  windows, mirroring `backup-prune.sh`.

## Metric lines

`metric-lines.js` builds one gauge's [exposition](https://prometheus.io/docs/instrumenting/exposition_formats/)
lines; a gauge with no samples prints nothing.

- `metrics/game-server-metrics.js`: `game_server_*`, what every game answers.
- `metrics/backup-metrics.js`: `game_server_backup_*`.
- `metrics/valheim-metrics.js`: `valheim_*` mods, world modifiers, raids and bosses.
- `metrics/zomboid-metrics.js`: `zomboid_*` zombie kills per player, world settings.
- `metrics/enshrouded-metrics.js`: `enshrouded_*` player-built bases, world settings.
- `metrics/backup-archive-metrics.js`: `valheim_backup_*` archive windows.

Metric naming rules live in [CLAUDE.md](../CLAUDE.md); a published name is an
interface, so grep `grafana/` before renaming one.
