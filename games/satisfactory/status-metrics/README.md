# Satisfactory status metrics

What only Satisfactory's exporter records and reports, beyond `game-plugin.js` and
`config.js`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

- The query goes to the game port: gamedig's lightweight query over UDP (up, name,
  build), then the server's own [HTTPS API](https://satisfactory.wiki.gg/wiki/Dedicated_servers/HTTPS_API)
  over TCP for the player count and session state. The API counts players without
  naming them, so every player metric that needs a name stays empty.
- `read-satisfactory-server-state.js`: runs that query and turns the count into
  the nameless players list the shared core expects. With a client-protection
  password set, `SATISFACTORY_API_TOKEN` keeps the API answering.
- `store-satisfactory-query-answer.js`: keeps the latest `QueryServerState` answer.
- `metrics/build-satisfactory-metrics.js`: `satisfactory_session`,
  `satisfactory_tech_tier`, `satisfactory_game_duration_seconds`,
  `satisfactory_average_tick_rate`, `satisfactory_game_paused`.
