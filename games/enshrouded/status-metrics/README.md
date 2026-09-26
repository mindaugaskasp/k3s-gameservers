# Enshrouded status metrics

What only Enshrouded's exporter records and reports, beyond `game-plugin.js`,
`config.js` and `migrations/`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

- `read-enshrouded-log.js`: players joining and leaving, their login permissions, the base count.
- `track-enshrouded-game-masters.js`: online game masters, by `CanKickBan` at login.
- `store-enshrouded-base-count.js`: the world's base count from the latest load or save.
- `read-enshrouded-settings.js`: the preset, and with a Custom one the settings changed from Default.
- `metrics/build-enshrouded-metrics.js`: `enshrouded_*` player-built bases, world settings.
