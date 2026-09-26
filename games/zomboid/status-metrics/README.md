# Zomboid status metrics

What only Zomboid's exporter records and reports, beyond `game-plugin.js`,
`config.js` and `migrations/`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

- `read-zomboid-deaths.js`: deaths from the game's `user` and `pvp` logs.
- `read-zomboid-character-names.js`: an account's current character, stored with each of its deaths.
- `store-zomboid-player-history.js`: zombie kills, and the character a player last died as.
- `read-zomboid-admins.js`: online admins, by admin/moderator/gm account role.
- `read-zomboid-sandbox-settings.js`: SandboxVars changed from their commented defaults.
- `metrics/build-zomboid-metrics.js`: `zomboid_*` zombie kills per player, world settings.
