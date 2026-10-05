# Palworld status metrics

What only Palworld's exporter records and reports, beyond `game-plugin.js` and
`config.js`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

- The query goes to the server's own [REST API](https://tech.palworldgame.com/category/rest-api)
  (basic auth, user `admin`, `PALWORLD_ADMIN_PASSWORD`), which names online players itself,
  so there is no log to follow. The game answers no public query protocol.
- `store-palworld-query-answer.js`: keeps the latest `/settings` and `/metrics` answers.
- `read-palworld-world-settings.js`: difficulty, death penalty and the other headline rules,
  then every rate changed from the game's default of 1.
- `metrics/build-palworld-metrics.js`: `palworld_world_setting`, `palworld_game_day`,
  `palworld_server_fps`.
