# Valheim status metrics

What only Valheim's exporter records and reports, beyond `game-plugin.js`,
`config.js` and `migrations/`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

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
