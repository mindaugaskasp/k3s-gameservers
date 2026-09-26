# Minecraft status metrics

What only Minecraft's exporter records and reports, beyond `game-plugin.js`,
`config.js` and `migrations/`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

- `read-minecraft-operators.js`: online admins, by name in the server's `ops.json`.
- `read-minecraft-world-settings.js`: difficulty, game mode, hardcore and PvP from `server.properties`.
- `metrics/build-minecraft-metrics.js`: `minecraft_world_setting`.

Player names and counts come from the server list ping, so there is no log to follow.
