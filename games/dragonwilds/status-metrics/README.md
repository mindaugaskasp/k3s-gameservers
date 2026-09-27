# Dragonwilds status metrics

What only Dragonwilds' exporter records and reports, beyond `game-plugin.js`,
`config.js` and `migrations/`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

gamedig has no Dragonwilds query, so the plugin's `readServerState` answers from the server log:

- `read-dragonwilds-log.js`: joins and leaves, the session's `ReadyToJoin`, world name, player limit,
  version, whether a join password is set, difficulty and hardcore state.
- `track-dragonwilds-server.js`: keeps that state in `STATUS_DIR` and reports the server up while it is
  ready to join and its log was written in the last 90 seconds (it logs a heartbeat every 30).
- `metrics/build-dragonwilds-metrics.js`: `dragonwilds_world_setting`.

The join and leave lines come from strings in the server binary; no player has joined yet to confirm them.
When nobody is left, the server says so, which clears the online list whatever was missed.
