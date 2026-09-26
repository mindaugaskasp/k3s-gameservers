# Status metrics per game

What each game's `games/<game>/status-metrics/` holds beyond its `game-plugin.js`,
`config.js` and `migrations/`. The shared part is in [status-metrics.md](status-metrics.md).

## Valheim

- `read-death-log.js`, `read-raid-log.js`: the death and raid lines the log hooks append.
- `store-raids.js`: every raid and when it started; the latest ones feed the website's raid list.
- `store-valheim-death-days.js`: the in-game day of each player's last death.
- `read-valheim-admins.js`: online admins, by the Steam ID on `ADMIN_LIST_FILE`.
- `read-valheim-status-files.js`: mod state from `mod-guard.sh`, the last player activity.
- `read-world-modifiers.js`: the `-modifier` pairs on the server's command line.
- `find-newest-world-metadata-file.js`: the newest `_main.<n>.db2`. In it, `read-defeated-bosses.js` finds the `defeated_*`
  keys (bosses, a few creatures); `read-valheim-game-day.js` takes `netTime` plus the time since the save as today's day.
- `classify-backups.js`: the `.play-clock` index and play-time retention windows, mirroring `backup-prune.sh`.
- `metrics/build-valheim-metrics.js`: `valheim_*` mods, world modifiers, raids, bosses, the last death's day.
- `metrics/build-backup-archive-metrics.js`: `valheim_backup_*` archive windows.

## Zomboid

- `read-zomboid-deaths.js`: deaths from the game's `user` and `pvp` logs.
- `read-zomboid-character-names.js`: an account's current character, stored with each of its deaths.
- `store-zomboid-player-history.js`: zombie kills, and the character a player last died as.
- `read-zomboid-admins.js`: online admins, by admin/moderator/gm account role.
- `read-zomboid-sandbox-settings.js`: SandboxVars changed from their commented defaults.
- `metrics/build-zomboid-metrics.js`: `zomboid_*` zombie kills per player, world settings.

## Enshrouded

- `read-enshrouded-log.js`: players joining and leaving, their login permissions, the base count.
- `track-enshrouded-game-masters.js`: online game masters, by `CanKickBan` at login.
- `store-enshrouded-base-count.js`: the world's base count from the latest load or save.
- `read-enshrouded-settings.js`: the preset, and with a Custom one the settings changed from Default.
- `metrics/build-enshrouded-metrics.js`: `enshrouded_*` player-built bases, world settings.
