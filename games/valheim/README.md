# Valheim

## Image and data

- **Image:**
  [`valheim-server-docker`](https://github.com/community-valheim-tools/valheim-server-docker).
  Configuration, cron and hooks are env vars in the chart's `values.yaml`.
  All times are UTC. Restarts happen on update only; `restart.cron` is off.
- **Data:** the world and config are on the PVC at `/config` (saves in
  `worlds_local`). The game install is a disposable subPath at `/opt/valheim`.
- **Seed:** the server has no seed option, so `files/create-seeded-world.py` writes a new world's
  metadata with `server.seed` before its first start, as the game's own `World.SaveWorldFWLData` does.
- **Backups:** every 10 minutes, only if players were on since the last one
  (`backup-gate.sh`), renamed by `files/backup-rename.sh` to `<date>-<time>-game-day-<n>.zip`. The last `backups.recentDays` of play stay in `/config/backups`; per
  `backupArchiveWindowDays` window the newest and oldest move to `archive/`
  (`files/backup-prune.sh`). Ages are play time in `backups/.play-clock`, so
  idle months age nothing; if the index is bad, pruning stops, deletes
  nothing, and the dashboard's "Cleanup index" goes red.
- **Restoring:** `make restore-backup` stops the server, unpacks the archive and starts it again.

## Who's online

Valheim's query protocol reports only a player count. For names,
`player-event.sh` runs from the image's
[log-filter hooks](https://github.com/community-valheim-tools/valheim-server-docker#log-filters)
and keeps one file per online character; `raid-event.sh` logs raids the same way. The sidecar exports them as
`game_server_player_session_seconds{name}`, and clears them when the count is 0.
Each scrape also records them in the player database ([player-database.md](../../docs/player-database.md)), exported
as `game_server_player_last_seen_timestamp_seconds{name}` so names outlive restarts.

## Alerts

`notify.sh` posts Discord embeds on stop and update from the image's [event hooks](https://github.com/community-valheim-tools/valheim-server-docker#event-hooks).
`announce-online.sh` posts "Server online" once Steam registers the server, after `alerts.onlineDelaySeconds`.

## Mods (BepInEx)

Mods are off by default. To turn them on:

1. Set `mods.enabled=true`.
2. Add each [Thunderstore](https://thunderstore.io/c/valheim/) package to `mods.json`
   (optionally with a `"version"` pin), then `make install-mods`; `make update-mods`
   later pulls newer releases of all of them.
3. Redeploy.

A Valheim update can land before a compatible BepInEx does, so
`mod-guard.sh` starts the server **unmodded** and alerts in either case:

- the loader libraries are broken
- the Steam build differs from `/config/mods-approved-build`

```sh
make mods-status                 # did mods load, and why not
make approve-mods && make restart   # with the fail-safe on, pulls the latest
                                    # mods.json releases, then records the build
```

## Broadcasts (ValheimRcon)

With the [ValheimRcon](https://thunderstore.io/c/valheim/p/Tristan/ValheimRcon/) DLL in
`/config/bepinex/plugins` and `VALHEIM_RCON_PASSWORD` set in `.env`, warn everyone in
game before a restart or update:

```sh
make broadcast MESSAGE="Server restarts in 10 minutes"
```

A game update restarts the server by itself: `update-countdown.sh` then counts down
in game from 30 minutes in 5-minute steps, and an empty server skips the wait.
The plugin listens inside the pod only; no Service or router forward exposes the port.

## Client mods (admin's Windows PC)

The Server Devcommands console only works if the admin's own client has the
mod too. `client/client-mods.ps1` installs or removes it; see
`Get-Help .\client-mods.ps1`. [r2modman](https://thunderstore.io/package/ebkr/r2modman/)
does the same job with a UI.
