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
- `player-files.js`: who is online now, and when each player was last seen
  (on the PVC, capped at 50 names).
- `player-counters.js`: per-player tallies on the volume -- seconds online,
  credited one scrape interval at a time, and deaths, counted by the log hook.
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
- `metrics/valheim-metrics.js`: `valheim_*` players, deaths, mods and world modifiers.
- `metrics/backup-archive-metrics.js`: `valheim_backup_*` archive windows.

Metric naming rules live in [CLAUDE.md](../CLAUDE.md); a published name is an
interface, so grep `grafana/` before renaming one.
