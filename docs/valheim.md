# Valheim

## Image and data

- **Image:**
  [`valheim-server-docker`](https://github.com/community-valheim-tools/valheim-server-docker).
  Configuration, update/restart/backup cron and hooks are env vars in the
  chart's `values.yaml`. All times are UTC.
- **Data:** the world and config are on the PVC at `/config` (saves in
  `worlds_local`). The game install is a disposable subPath at `/opt/valheim`.
- **Backups:** every 10 minutes, only if players were on since the last one
  (`backup-gate.sh`), named `<date>-<time>-game-day-<n>.zip` (UTC, in-game
  day). The last `backups.recentDays` of play stay in `/config/backups`; per
  `backupArchiveWindowDays` window the newest and oldest move to `archive/`
  (`files/backup-prune.sh`). Ages are play time in `backups/.play-clock`, so
  idle months age nothing; if the index is bad, pruning stops, deletes
  nothing, and the dashboard's "Cleanup index" goes red.
- **Restoring:** `make restore-backup` stops the server, unpacks the archive
  and starts it again.

## Who's online

Valheim's query protocol reports only a player count. For names,
`player-event.sh` runs from the image's
[log-filter hooks](https://github.com/community-valheim-tools/valheim-server-docker#log-filters)
and keeps one file per online character. The sidecar exports them as
`valheim_player_online{name}`, and clears them when the count is 0.
Each scrape also records them in the player database (see status-metrics.md), exported
as `game_server_player_last_seen_timestamp_seconds{name}` so names outlive restarts.

## Alerts

Discord embeds are sent on start, stop and update, using the image's
[event hooks](https://github.com/community-valheim-tools/valheim-server-docker#event-hooks).

## Mods (BepInEx)

Mods are off by default. To turn them on:

1. Set `mods.enabled=true`.
2. Put plugin DLLs in `/config/bepinex/plugins`.
3. Redeploy.

A Valheim update can land before a compatible BepInEx does, so
`mod-guard.sh` starts the server **unmodded** and alerts in either case:

- the loader libraries are broken
- the Steam build differs from `/config/mods-approved-build`

```sh
make mods-status                 # did mods load, and why not
make approve-mods && make restart
```

## Client mods (admin's Windows PC)

The Server Devcommands console only works if the admin's own client has the
mod too. `games/valheim/client-mods.ps1` installs or removes it; see
`Get-Help .\client-mods.ps1`. [r2modman](https://thunderstore.io/package/ebkr/r2modman/)
does the same job with a UI.
