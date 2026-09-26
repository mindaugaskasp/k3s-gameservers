# Terraria status metrics

What only Terraria's exporter records and reports, beyond `game-plugin.js`,
`config.js` and `migrations/`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

- `config.js`: the TShock REST token gamedig's `terrariatshock` query needs.
- `track-terraria-admins.js`: online admins, by the TShock group each player's status names.

Player names and counts come from TShock's REST status, so there is no log to follow.
